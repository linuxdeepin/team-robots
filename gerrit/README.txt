dps.pl:
  运行: morbo dps.pl
  部署: 10.0.0.210:3000

  * GET http://10.0.0.210:3000/dps
      参数:
        project
        changeid
        patchset

      功能: 添加DPS任务
      适用: 由jenkins调用

  * POST http://10.0.0.210/dps/:task
      参数:
        task:    任务id(DPS)
        message: 评论内容(post数据)

      功能: 添加gerrit评论
      适用: 由DPS调用

dps.ids: 项目名(gerrit)与id(DPS)的对应表
