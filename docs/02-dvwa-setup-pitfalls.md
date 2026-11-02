# 我把 DVWA 搭进虚拟机，踩了三个坑

> 家庭网络安全实验室系列第二篇。第一篇讲 SQL 注入，这篇讲环境本身——因为环境没搭对，后面的实验全是假象。

## 想做什么

想有一套能反复重来、随时快照回滚的靶场。要求不高：本机虚拟机、一条命令装好、靶场十关能跑。

选了 DVWA + Ubuntu 22.04 + Apache + PHP + MariaDB 这套最经典组合。

## 第一步：一键脚本

手动装一遍太麻烦，写成一个脚本：

```bash
#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  apache2 mariadb-server php libapache2-mod-php \
  php-mysql php-gd php-curl php-xml php-mbstring unzip
rm -rf DVWA-master && unzip -oq dvwa-master.zip
sudo rm -rf /var/www/html/dvwa
sudo cp -r DVWA-master /var/www/html/dvwa
sudo systemctl enable --now mariadb
sudo mysql -e "CREATE DATABASE IF NOT EXISTS dvwa DEFAULT CHARACTER SET utf8mb4;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd';"
sudo mysql -e "GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"
sudo cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php
```

脚本跑完，浏览器打开 `localhost/dvwa/setup.php`，点建库按钮，装了 admin/password，能登录。

到这里看起来一切顺利。然后开始第一关——页面全白。

## 坑一：PHP 8.1 让 mysqli 抛异常，白屏

现象：输入 `1'`，浏览器整页空白。命令行请求也拿不到任何输出。

第一反应是“注入没生效”，但正常查询 `1` 是好的。于是去看 Apache 日志：

```bash
tail -20 /var/log/apache2/error.log
```

里面躺着一行：

```
PHP Fatal error: Uncaught mysqli_sql_exception: You have an error in your SQL syntax ...
near ''1''' at line 1 in /var/www/html/dvwa/vulnerabilities/sqli/source/low.php
```

原因清楚了：PHP 8.1 开始，mysqli 默认把错误当成异常抛出（`MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT`）。而 DVWA 的 low 级代码是这么写的：

```php
$result = mysqli_query($db, $query) or die('<pre>' . mysqli_error($db) . '</pre>');
```

`or die` 只能接住返回 false 的情况，接不住异常。异常直接冒到最外层，PHP 输出 500，页面就白了。

修法：在 `config/config.inc.php` 的 `<?php` 后面加一行：

```php
mysqli_report(MYSQLI_REPORT_OFF);
```

然后重启 apache。再打 `1'`，熟悉的 SQL 语法错误终于出现了。

**教训**：网上教程多数跑在 PHP 7 或更早，报错方式不一样。遇到“页面空白、日志里有 Uncaught”，先想语言默认行为变了，不要一头扎进 payload。

## 坑二：安全级别存在 cookie 里

后来用脚本批量测 payload，发现 `1'` 还是没反应，但浏览器里是好的。

排查半天，发现 DVWA 的安全级别不是存在 session 里，而是读 cookie：

```
Cookie: security=low
```

脚本登录后默认级别是 `impossible`，于是每次请求都走安全分支：参数化查询 + 类型校验，注入当然“没反应”，连报错都不会有。

**教训**：自动化测靶场前，先确认靶场的“模式开关”到底在哪。DVWA 这种放在 cookie 里的设计，最容易被当成“靶场坏了”。

## 坑三：Brute Force 表单是 GET 不是 POST

暴力破解关，脚本按 POST 提交：

```python
requests.post(url, data={'username': 'admin', 'password': pwd, 'Login': 'Login'})
```

试了二十个密码全部失败，包括正确的 `password`。

去看页面源码，表单是：

```html
<form action="#" method="GET">
```

**教训**：打靶之前先看一眼表单的 method。这个坑不危险，但特别浪费信心。

## 收尾建议

1. 每装好一步就打个快照，改崩了直接回滚，比修快。
2. 别把靶场和真实数据放同一台机器；这台虚拟机只跑靶场。
3. 用 `php -S` 跑一份副本当对照，能快速区分“是靶场问题还是 web 服务器问题”。
4. 日志优先于猜测：`error.log` 里基本都有答案。

## 下一篇

第三篇写 Wazuh：把这套靶场的攻击日志接进日志平台，让告警来找我，而不是我翻日志找告警。
