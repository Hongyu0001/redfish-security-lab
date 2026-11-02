# 我用 Wazuh 搭了一个小型 SOC

> 家庭网络安全实验室系列第三篇。目标不是堆组件，是让“攻击发生”和“我知道”之间没有断点。

## 起因

药店那套追溯码台账，最初的问题不是没有记录，是出了错没人知道为什么错、什么时候错的。日志这东西平时不起眼，出事的时候是唯一的证据链。

安全也一样。靶场里的攻击打得再漂亮，如果没有一处地方把它们记下来、判断出来、告我一声，那就只是一次次手工演示。

所以想搭一个最小的 SOC：能采、能解析、能出规则、能告警、能处置。

## SOC 最小闭环

一套能用的安全运营中心，拆开看就五步：

1. **采集**：日志从哪来（系统日志、Web 访问日志、应用日志）。
2. **解析**：把非结构化文本变成字段（来源 IP、请求路径、响应码）。
3. **规则**：什么组合算可疑（同一 IP 短时间内大量 40x 加 SQL 关键字）。
4. **告警**：达到阈值就报警，带等级和描述。
5. **处置**：人看到告警后能追溯、能封禁、能取证。

很多教程停在第四步，第五步才是真正值钱的地方。

## 环境

- 管理端：Ubuntu 22.04 虚拟机，4G 可用内存
- 采集端：DVWA 靶场所在的本机（Apache access.log）
- 扩展：店里的 Windows 10 台式，装 agent 采系统安全日志

选 Wazuh 的原因是它把 host-based 采集、规则引擎、告警都做全了，而且单机 manager 就能跑，不像某些方案一上来就要一堆容器。

## 部署

四步，都在管理端做：

```bash
# 1. 加官方源
wget -qO /tmp/wazuh.key https://packages.wazuh.com/key/GPG-KEY-WAZUH
sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/wazuh.gpg /tmp/wazuh.key
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | sudo tee /etc/apt/sources.list.d/wazuh.list

# 2. 安装
sudo apt-get update -y
sudo apt-get install -y wazuh-manager

# 3. 启用
sudo systemctl enable --now wazuh-manager

# 4. 确认
sudo /var/ossec/bin/wazuh-control status
```

装的是 4.14.9，包 596 MB，解压后约 1.2 GB。

## 接入日志

在 `/var/ossec/etc/ossec.conf` 的 `</ossec_config>` 前加：

```xml
<localfile>
  <log_format>apache</log_format>
  <location>/var/log/apache2/access.log</location>
</localfile>
```

重启后 `alerts.log` 里就能看到访问日志被解析了。

## 规则设计

六个检测点，对应 DVWA 的六类攻击：

| 规则 | 匹配特征 | 等级 |
| --- | --- | --- |
| 100201 | `union select` | 12 |
| 100202 | `' OR` | 12 |
| 100203 | `-- -` | 10 |
| 100204 | `%3B`（命令分隔符） | 13 |
| 100205 | `%3Cscript%3E` | 10 |
| 100206 | `etc/passwd` | 12 |

规则不长，关键是“用真实攻击流量验证它真的会响”——这一步待实测后填。

## 实测

用 SQL 注入 payload 打 DVWA：

```
GET /dvwa/vulnerabilities/sqli/?id=1%27%20UNION%20SELECT%20user%2Cpassword%20FROM%20users--%20-
```

`alerts.log` 里出现了两条：

第一条是 Wazuh 内置规则先接手：

```
Rule: 31106 (level 6) -> 'A web attack returned code 200 (success).'
Src IP: 127.0.0.1
```

第二条是自定义规则把它升级：

```
Rule: 100203 (level 10) -> 'DVWA: SQL injection attempt (comment truncation)'
Src IP: 127.0.0.1
127.0.0.1 - - [02/Nov/2026:13:08:31 +0800] "GET /dvwa/vulnerabilities/sqli/?id=1%27%20UNION%20SELECT..."
```

到这里链路是通的：攻击发生 → 日志落盘 → Wazuh 解析 → 内置规则识别 → 自定义规则定级 → 告警落库，全程不用人盯。

## 三个真坑

1. **规则文件不能带 `<?xml version="1.0"?>` 声明**。Wazuh 用的是自研 XML 解析器，遇到声明直接 `Bad attribute closing for 'encoding'` 退出。官方规则文件都是 `<group>` 开头，照着写就行。
2. **4.x 没有 `url_contains`**。网上老教程里的这个标签是 OSSEC 时代的，现在得用 `<match>`（整条日志字符串）或 `<regex>`。
3. **自定义规则要挂 `<if_sid>`**。Wazuh 内置规则先匹配，命中后就不再往下找；想让自己的规则生效，得写成内置规则的子规则，比如 `<if_sid>31106</if_sid>`。

还有个小坑：`sudo bash 脚本` 里用 `~` 会展开成 `/root`，脚本里引用用户目录要写绝对路径。

## 内存取舍

这台虚拟机只有 4G 可用内存，Wazuh 的 indexer（OpenSearch）单机就要 1G 以上，dashboard 还要 Node。所以先只装 manager：

- 能做：采集、解析、规则、告警、`alerts.log` 追溯。
- 不做：可视化大屏、搜索界面。
- 为什么可以接受：告警文本已经能回答“谁、什么时候、打了什么”，可视化对单人运维是锦上添花。

等有条件（或者放店里台式上），再补 indexer + dashboard。

## 下一步

（待补：接入 Windows 台式、Sysmon、告警分级、封禁动作）

## 结语

（待补）
