# DVWA 十关通关记录

2026-11-02 实测，安全级别 low，本地虚拟机。每关只记四件事：漏洞点在哪、怎么打的、打出了什么、怎么修。

## 1. SQL Injection

- 漏洞点：`$query = "SELECT first_name, last_name FROM users WHERE user_id = '$id';"`
- payload：`1'` → `1' OR '1'='1` → `1' UNION SELECT user,password FROM users-- -`
- 结果：`1'` 报语法错误；OR 恒真返回 5 个用户；UNION 吐出 5 个 MD5 哈希
- 修复：`is_numeric` 校验 + prepared statement

## 2. Command Injection

- 漏洞点：`$cmd = "ping -c 4 " . $ip; shell_exec($cmd);`
- payload：`127.0.0.1; id`、`127.0.0.1 | cat /etc/passwd`
- 结果：执行系统命令、读出整份 /etc/passwd
- 修复：`escapeshellarg()` + IP 白名单

## 3. CSRF

- 漏洞点：改密码走 GET，无 token、无原密码验证
- payload：`?password_new=x&password_conf=x&Change=Change`
- 结果：一个 GET 请求改掉管理员密码，验证后已改回
- 修复：anti-CSRF token + 原密码确认

## 4. Brute Force

- 漏洞点：表单 GET 提交、无锁定、无延迟
- payload：字典循环 `?username=admin&password=xxx&Login=Login`
- 结果：第 2 个候选（password）即命中
- 修复：失败计数锁定、指数延迟、验证码

## 5. File Inclusion

- 漏洞点：`include($_GET['page'])` 无过滤
- payload：`?page=/etc/passwd`
- 结果：系统账户文件被读进页面
- 修复：include 白名单 + `realpath` 校验

## 6. File Upload

- 漏洞点：上传目录无类型校验，php 文件可直接执行
- payload：上传 `probe_xxxx.php`（回显固定标记）
- 结果：访问 `/hackable/uploads/probe_xxxx.php` 执行成功
- 修复：扩展名白名单、重命名、上传目录禁执行

## 7. XSS Reflected

- 漏洞点：`echo $_GET['name']` 未编码
- payload：`<script>alert(1)</script>`
- 结果：脚本原样回显进页面
- 修复：`htmlspecialchars` + CSP

## 8. XSS Stored

- 漏洞点：留言板直接存原文、原样输出
- payload：留言内容塞 `<script>alert('stored')</script>`
- 结果：存储后每次打开页面都执行
- 修复：入库前校验、输出时编码

## 9. SQL Injection Blind

- 漏洞点：注入点存在但页面不显示数据，只回显 exists / MISSING
- payload：`1' AND 1=1#` / `1' AND 1=2#`
- 结果：真条件 exists、假条件 MISSING，布尔差异成立
- 修复：同第一关，参数化

## 10. XSS (DOM)

- 漏洞点：前端 `document.write` 直接输出 URL 片段
- payload：`#<script>alert('dom_xss')</script>`
- 结果：浏览器弹出对话框
- 修复：`textContent` 替代 `innerHTML`，不执行 URL 里的脚本

## 小结

十关的共同点：所有漏洞都出在“用户输入被直接当成代码或结构使用”，而修复的共同点是把输入当数据——参数化查询、编码输出、白名单、token。工具打不了千疮百孔的系统，能打进去的都是这一条根本问题。
