# redfish-security-lab

家庭网络安全实验室：DVWA 十关通关记录 + Wazuh 最小 SOC 实践。

全部实验在本地虚拟机完成，不涉及任何真实业务系统。

## 目录

```
├── docs/
│   ├── 01-sql-injection.md         # 一次 SQL 注入从原理到修复的完整复盘
│   ├── 02-dvwa-setup-pitfalls.md   # 搭 DVWA 踩的三个坑
│   ├── 03-wazuh-soc.md             # 用 Wazuh 搭一个小型 SOC
│   ├── 04-dvwa-ten-levels.md       # 十关通关记录
│   └── 05-security-checklist.md    # 给非渗透岗的安全巡检清单
├── scripts/
│   ├── setup-dvwa.sh           # DVWA 一键部署
│   └── setup-wazuh-rules.sh    # Wazuh 规则与日志采集配置
├── rules/
│   └── local_rules.xml         # DVWA 攻击检测规则
└── screenshots/                # 实测截图
```

## 环境

- Ubuntu 22.04 / Apache 2.4.52 / PHP 8.1 / MariaDB 10.6
- DVWA（master）
- Wazuh 4.14.9（manager 单机）
- 虚拟机 5.8G 内存 / 59G 磁盘

## 快速开始

```bash
# 1. 部署靶场
bash scripts/setup-dvwa.sh
# 浏览器打开 http://localhost/dvwa/setup.php 建库，账号 admin/password

# 2. 部署 Wazuh
bash scripts/setup-wazuh.sh
# 挂规则
sudo bash scripts/setup-wazuh-rules.sh
```

## 十关进度

| # | 关卡 | 状态 |
| --- | --- | --- |
| 1 | SQL Injection | ✅ |
| 2 | Command Injection | ✅ |
| 3 | CSRF | ✅ |
| 4 | Brute Force | ✅ |
| 5 | File Inclusion | ✅ |
| 6 | File Upload | ✅ |
| 7 | XSS Reflected | ✅ |
| 8 | XSS Stored | ✅ |
| 9 | SQL Injection (Blind) | ✅ |
| 10 | XSS (DOM) | ✅ |

## 踩过的坑

- PHP 8.1 的 mysqli 默认抛异常，DVWA 的 `or die()` 接不住，注入 payload 直接白屏。
- DVWA 的安全级别存在 cookie（`security=low`），不在 session 里。
- Brute Force 表单是 GET 不是 POST。
- Wazuh 规则文件不能带 XML 声明；4.x 没有 `url_contains`；自定义规则要挂 `<if_sid>`。

## 声明

所有攻击都在本地虚拟机靶场中进行，未针对任何第三方系统。日志与截图已做脱敏处理。
