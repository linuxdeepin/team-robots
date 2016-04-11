**描述**: 作为jenkins-tags-monitor的运行脚本以实时通知git tag操作

该脚本作为jenkins-tags-monitor built-in shell而编写, 不过也支持普通命
令操作, 以方便出现问题时人为干预, 避免信息丢失. 脚本实现时使用了任务队列
的概念, 支持多进程同时运行而不会阻塞.

## 依赖

- bash
- git
- sed
- awk
- /usr/sbin/sendmail

## 使用说明

默认作为jenkins built-in shell来运行, 若脚本有更新, 可以
访问
[jenkins配置页面](https://ci.deepin.io/view/tools/job/tags-monitor/configure)
重新粘贴一份源码即可

若由于网络等原因导致发送email失败, 则该任务失败, 不过任务信息仍保存在
jenkins主机**~/workspace/tags-monitor/tasklist**文件, 这时可以选择
re-trigger jenkins任务, 也可以直接ssh下执行脚本, 无需添加参数, 会自动
将未完成的任务重新执行一遍
```sh
cd ~/workspace/tags-monitor
./jenkins-tags-monitor.sh
```

当然也可以使用参数以创建新任务
```sh
./jenkins-tags-monitor.sh only-for-test v1.2.1.1
```

## 配置sendmail
1.  安装ssmtp包

        # apt-get install ssmtp
2.  配置smtp帐号信息, 编辑 /etc/ssmtp/ssmtp.conf, 注意原mailhub等条目需要删除

        mailhub=smtp.exmail.qq.com:465
        UseTLS=YES
        AuthUser=jenkins@deepin.com
        AuthPass=<pass>
3.  配置 /etc/ssmtp/revaliases, 假设用户名为jenkins

        root:jenkins@deepin.com:smtp.exmail.qq.com:465
        jenkins:jenkins@deepin.com:smtp.exmail.qq.com:465
4.  测试

        $ echo 'Subject: test' > /tmp/mailmsg
        $ echo 'Message-ID: twsegac21r4.jenkins@deepin.com>' >> /tmp/mailmsg
        $ echo 'Content-Type: text/plain; charset="utf-8"' >> /tmp/mailmsg
        $ echo '' >> /tmp/mail
        $ echo 'content' >> /tmp/mailmsg
        $ /usr/sbin/sendmail <user>@deepin.com < /tmp/mailmsg

## 抓取Github Email回复地址

1. 以deepin-jenkins身份登录Github
2. 进入特定issue页面如[Release notification](https://github.com/linuxdeepin/developer-center/issues/41)
3. 点击页面右侧的**Subscribe**按钮进行订阅
4. 以其他身份登录Github, 在该issue页面留言
5. 登录jenkins@deepin.com邮箱, 可以看到别人的留言通知, 回复该邮件, 即
   能获取类似**reply+xxxxx@reply.github.com**格式的Github Email回复
   地址

## License

GNU General Public License Version 3
