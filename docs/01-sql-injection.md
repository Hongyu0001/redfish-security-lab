# 一次 SQL 注入从原理到修复的完整复盘

> 这是“家庭网络安全实验室”系列的第一篇。全部实验在本地虚拟机完成，靶场是 DVWA，不涉及任何真实业务系统。

## 起因

以前看教程，SQL 注入的演示永远是“输入 `' or 1=1#`，然后整张表出来了”，看起来像变魔术。真正自己搭一遍才发现，能跑通和讲明白是两回事：为什么单引号能出表、为什么 UNION 能读别人的密码、修的时候为什么只有参数化才彻底。

这篇把这三件事从头到尾走一遍。

## 环境

- Ubuntu 22.04，Apache 2.4.52，PHP 8.1，MariaDB 10.6
- DVWA（Damn Vulnerable Web Application），安全级别 low
- 访问 `http://localhost/dvwa/`，账号 admin

DVWA 的 SQL Injection 页面长这样：输入一个 User ID，返回这个用户的名和姓。

## 第一步：确认注入点

输入正常的 `1`，页面返回：

```
ID: 1
First name: admin
Surname: admin
```

再输入 `1'`（多一个单引号），页面报错：

```
You have an error in your SQL syntax; check the manual that corresponds to your MariaDB
server version for the right syntax to use near ''1''' at line 1
```

报错里那个 `''1'''` 就是线索——我们输进去的单引号被原样拼进了 SQL 语句，把字符串截断了。

去看源码，果然如此：

```php
$id = $_REQUEST['id'];
$query = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";
$result = mysqli_query($GLOBALS["___mysqli_ston"], $query);
```

用户的输入直接拼进 SQL，没有类型校验、没有转义、没有参数化。

## 第二步：布尔恒真，绕过条件

既然单引号能闭合，那就补一句恒真的条件：

```
1' OR '1'='1
```

返回变成五个用户：

```
ID: admin / Gordon Brown
ID: Hack Me / Pablo Picasso
ID: Bob Smith
```

原理：语句变成 `WHERE user_id = '1' OR '1'='1'`，`'1'='1'` 永远成立，WHERE 条件等于没写。

## 第三步：UNION 联合查询，把密码读出来

```sql
1' UNION SELECT user,password FROM users-- -
```

`-- -` 是 SQL 注释，把原语句后面的单引号注释掉，让拼接后的语句仍然语法完整。返回结果里，第一列变成了用户名、第二列变成了密码哈希：

```
admin  5f4dcc3b5aa765d61d8327deb882cf99
gordonb e99a18c428cb38d5f260853678922e03
1337   8d3533d75ae2c3966d7e0d4fcc69216b
pablo  0d107d09f5bbe40cade3de5c71e9e9b7
smithy 5f4dcc3b5aa765d61d8327deb882cf99
```

`5f4dcc3b5aa765d61d8327deb882cf99` 是 `password` 的 MD5。没有加盐的哈希，在这个时代约等于明文。

到这一步，攻击的完整链条就清楚了：一个没过滤的输入框 → 看库结构 → 读出账号密码。

## 为什么能成功

一句话：**数据被当成了代码执行**。

SQL 是一条“语句”，用户输入是“数据”。拼接的时候，数据库分不清哪部分是开发者写的、哪部分是用户填的。用户填一个单引号，就能改变语句本身的语法结构。

这不是 DVWA 故意的愚蠢，而是所有拼接 SQL 的应用的共同问题——只是 DVWA 把它放大到最直观。

## 怎么修

DVWA 的 impossible 级别给了标准答案，两步：

**第一，先校验类型。**

```php
$id = $_GET['id'];
if (!is_numeric($id)) {
    exit("User ID must be a number.");
}
```

**第二，用预编译语句（prepared statement）。**

```php
$data = $db->prepare('SELECT first_name, last_name FROM users WHERE user_id = (:id);');
$data->bindParam(':id', $id, PDO::PARAM_INT);
$data->execute();
```

预编译的关键在于：SQL 语句的结构在编译阶段就固定了，绑定进去的参数永远只当数据，不会被解析成语法。哪怕参数里写满了 `' OR 1=1--`，数据库也只当作一个字符串去找。

对 MariaDB 来说，还有一条不推荐但常见的兜底：`mysqli_real_escape_string()`。它能转义单引号，但依赖字符集正确配置，而且只处理引号、不处理数字型注入。真正稳妥的还是参数化。

## 防守方自查清单

如果我是甲方，会看这几条：

1. 代码里有没有字符串拼接 SQL（grep `$query = "SELECT`）。
2. 所有输入是否都走了参数化，尤其是排序字段、表名这种参数化不好写的地方。
3. 数据库账号是否最小权限——Web 账号不应该有 DROP 权限。
4. 密码是否加盐（bcrypt / Argon2），哪怕被拖库也不至于明文。
5. 有没有 WAF 规则兜底。

## 结尾

这次实验最有价值的不是 payload 本身，而是理解了一句话：**安全问题的根，往往不在“有没有做过滤”，而在“有没有把数据和代码分开”**。过滤是补丁，参数化是结构。

下一篇写撞到的真实坑：为什么这套东西在 PHP 8.1 上第一个 payload 就直接白屏，以及怎么在日志里把它找出来。
