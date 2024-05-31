function cz_webcall() {
  const DEFAULT_OPT = {
    isLoad: false,
    webcallIframeId: 'CZ-WEBCALL-WIN',
    webcallWrapperId: 'CZ-WEBCALL-WIN-WRAPPER',
    webcallImgId: 'CZ_WEBCALL_WIN_IMG',
    webcallTimeId: 'CZ-WEBCALL-WIN-TIME',
    webcallFloatId: 'CZ-WEBCALL-BOX',
    msg: {},
    media: '',
    outTime: 5000,
    autoTime: 3000,
    timer: null,
    minWinHeight: 40,
    winHeight: 530,
    winWidth: 350,
    config: {},
    configCode: '',
    isDown: false,
    isShowIframe: false,
    nowTime: '',
    floatStatus: 1, // 浮动图标状态
    jsPms: null,
    lastPostion: {},
    pst: 0, // 是否定位显示
    option: {
      debug: true,
      // 是否拖拽，默认为true
      isDrag: true,
      // 是否展示悬浮球
      showFloat: true,
      // 设置固定位置
      position: {
        left: null,
        right: null,
        top: null,
        bottom: null,
      },
      // 设置可选的主叫号码
      callNum: [],
      // 设置铃声大小
      volume: 1,
      // 设置是否禁止手动输入外呼
      isBanCall: false,

      // 是否使用webRTC
      isWebRTC: true,

      // 来电反馈消息事件
      handlerCallIn: function () {},
      // 外呼报错反馈信息处理
      handlerCallOutErr: function () {},
      // 挂断电话反馈事件
      handlerHangUp: function() {},
      // 坐席接通
      handlerAgentPickUp: function() {},
      // 客户接通
      handlerCustomerPickUp: function() {},
      // 接收dtmf事件的执行结果
      handlerDTMFCallback: function () {},
      // 接收设置外呼结果函数
      handlerAutocallCallback: function () {},

      // 初始化结果返回事件
      handlerInitResult: function () {}
    },
  }

  var _this = this

  var opt = {
    ...DEFAULT_OPT,
  }

  this.api = {
    /**
     * @param phone 被叫手机号
     * @param type 外呼的方式：1：pc(默认), 4:双呼,
     * @param call_num 主叫号码
     * */
    callNum: function (phone, type = 1, call_num = '') {
      _this.sendMsg({
        type: 'api',
        data: {
          api: 'callNum',
          data: {
            phone: phone.toString().replace(/[^0-9]/g, ''),
            call_num,
            type,
          },
        },
      })
    },

    hangup: function() {
      _this.sendMsg({
        type: 'api',
        data: {
          api: 'hangup'
        }
      })
    },

    setAutoCallVal: function (val) {
      _this.sendMsg({
        type: 'api',
        data: {
          api: 'autoAnswer',
          data: {
            autoAnswer: val
          }
        }
      })
    },

    dtmf: function (val) {
      _this.sendMsg({
        type: 'api',
        data: {
          api: 'dtmf',
          data: val
        }
      })
    },

    // type 开启还是关闭自动外呼: 'in' 开启, 'out' 关闭
    // proID 外呼策略proID
    wincallAutoCall: function (type, proID = '') {
      _this.sendMsg({
        type: 'api',
        data: {
          api: 'setAutoCall',
          data: {
            type,
            proID
          }
        }
      })
    },

    destroyCallback: function () {
      for(let key in opt.option) {
        if(typeof opt.option[key] === 'function') {
         opt.option[key] = function(){} 
        }
      }
    }
  }

  this.init = function (option) {
    opt.jsPms = this.getProbeId()
    if (!!option) {
      if (Object.prototype.toString.call(option) === '[object Object]') {
        opt.option = {
          ...opt.option,
          ...option,
        }
      } else {
        console.log('初始化传递参数必须为Obejct类型')
      }
    }
    console.log(opt.jsPms)

    opt.lastPostion = this.isJSON(window.localStorage.webcallIframePostion)
      ? JSON.parse(window.localStorage.webcallIframePostion)
      : {}

    this.initwebcall()
    this.listenOpt()
    this.browserRedirect()
    this.getMsg()
  }

  this.isJSON = function (str) {
    if (typeof str == 'string') {
      try {
        var obj = JSON.parse(str)
        if (typeof obj == 'object' && obj) {
          return true
        } else {
          return false
        }
      } catch (e) {
        console.log('error：' + str + '!!!' + e)
        return false
      }
    }
  }

  // 监听配置参数是否变化
  this.listenOpt = function () {
    Object.defineProperties(opt, {
      setIsShowIframe: {
        enumerable: true,
        set: function (newValue) {
          this.isShowIframe = newValue

          document.querySelector(
            `#${opt.webcallIframeId}`
          ).style.display = newValue ? 'block' : 'none'
        },
      },
      setNowTime: {
        enumerable: true,
        set: function (newValue) {
          this.nowTime = newValue

          if (!!newValue && [1, 4, 5, 6, 7].includes(this.floatStatus)) {
            document.querySelector(`#${opt.webcallTimeId}`).innerHTML = newValue
          }
        },
      },
      setFloatStatus: {
        enumerable: true,
        set: function (newValue) {
          this.floatStatus = newValue

          let aObj = document.querySelector(`#${opt.webcallFloatId}`) || {},
            aObjT = document.querySelector(`#${opt.webcallTimeId}`) || {},
            aImg = document.querySelector(`#${opt.webcallImgId}`) || {}

            aObjT.style.paddingTop = '0px'

          switch (newValue) {
            case 1:
              aObj.style.background = '#088a70'
              aObj.style.color = '#088a70'
              break
            case 2:
              aObj.style.background = '#F56C6C'
              aObj.style.color = '#F56C6C'
              aObjT.innerHTML = '设备问题'
              break
            case 201:
              aObj.style.background = '#F56C6C'
              aObj.style.color = '#F56C6C'
              aObjT.innerHTML = '账号未配置'
              break
            case 202:
              aObj.style.background = '#F56C6C'
              aObj.style.color = '#F56C6C'
              aObjT.style.paddingTop = '20px'
              aObjT.innerHTML = '注册失败'
              break
            case 203:
              aObj.style.background = '#F56C6C'
              aObj.style.color = '#F56C6C'
              aObjT.innerHTML = '语音设备未授权'
              break
            case 501:
              aObj.style.background = '#F56C6C'
              aObj.style.color = '#F56C6C'
              aObjT.innerHTML = '坐席迁出'
              break
            case 3:
              aObj.style.background = '#e6a23c'
              aObj.style.color = '#e6a23c'
              aObjT.innerHTML = '网络延迟'
              break
            case 4:
            case 6:
              // 忙碌，通话中
              aObj.style.background = '#f12043'
              aObj.style.color = '#f12043'
              break
            case 5:
              // 事后
              aObj.style.background = '#409EFF'
              aObj.style.color = '#409EFF'
              break
            case 7:
              // 呼叫中
              aObj.style.background = '#d76004'
              aObj.style.color = '#d76004'
              break
          }
        },
      },
    })
  }

  this.getProbeId = function () {
    for (
      var e = /(webcall\d{1,}\.\d{1,}|webcall)\.js?/, t = document.getElementsByTagName('script'), i = 0;
      i < t.length;
      i++
    ) {
      var n = t[i].src
    
      if (n && e.test(n)) {
        var s = n.toString().split('?')[1]
        var obj = {}
        s.split('&').forEach((item) => {
          var str = item.split('=')
          if (!!str[0]) obj[str[0]] = str[1]
        })
        return obj
      }
    }
    return console.error('fail to find probe'), null
  }

  this.initwebcall = function () {
    var aDivWrp = document.createElement('div')
    aDivWrp.id = opt.webcallWrapperId
    aDivWrp.style = `z-index: 2147483637; min-height: 80px; min-width: 80px; user-select: none; position: fixed;`

    var aDivFloat = document.createElement('div')
    aDivFloat.id = opt.webcallFloatId
    aDivFloat.style = `width: 80px; height: 80px; text-align: center; border-radius: 80px; background: #088a70; color: #088a70; position:absolute;font-size:12px; user-select: none;`

    var aImg = document.createElement('div')
    aImg.id = opt.webcallImgId
    aImg.style = `width: 28px; height: 28px; display: block; margin: 16px auto 6px auto; font-size: 6px;`

    var imfIcon = document.createElement('div')
    imfIcon.style = `
      position: relative;
      display: inline-block;
      font-size: 1em; /* control icon size here */
    `
    var imgCloud = document.createElement('div')
    imgCloud.className = 'cloud'
    imgCloud.style = `
      position: absolute;
      z-index: 1;
      top: 39%;
      left: 50%;
      width: 3.6875em;
      height: 3.6875em;
      margin: -1.84375em;
      background: currentColor;
      border-radius: 50%;
      box-shadow:
        currentColor -2.1875em 0.6875em 0 -0.6875em,
        currentColor 2.0625em 0.9375em 0 -0.9375em,
        0 0 0 0.375em #fff,
        -2.1875em 0.6875em 0 -0.3125em #fff,
        2.0625em 0.9375em 0 -0.5625em #fff;
    `

    // this.addStylesheetRules([
    //   [`.cloud:after`,
    //     ['content', ""],
    //     ['position', 'absolute'],
    //     ['bottom', '0'],
    //     ['left', '-0.5em'],
    //     ['display', 'block'],
    //     ['width', '4.5625em'],
    //     ['height', '1em'],
    //     ['background', 'currentColor'],
    //     ['box-shadow', '0 0.4375em 0 -0.0625em #fff']
    //   ]
    // ])

    imfIcon.appendChild(imgCloud)
    aImg.appendChild(imfIcon)
    aDivFloat.appendChild(aImg)

    var aSpan = document.createElement('span')
    aSpan.id = opt.webcallTimeId
    aSpan.innerHTML = '初始化'
    aSpan.style = 'width: 60px; position: absolute; left: 10px; color: #fff;'
    aDivFloat.appendChild(aSpan)
    aDivWrp.appendChild(aDivFloat)

    var aIfr = document.createElement('iframe')
    aIfr.id = opt.webcallIframeId
    aIfr.allow = 'geolocation; microphone; camera; midi; encrypted-media;'
    aIfr.name = opt.webcallIframeId
    aIfr.scrolling = 'no'
    aIfr.style = `position: absolute; width: 650px; height: 70px;border: 0; display: none;right: 90px;`
    aDivWrp.appendChild(aIfr)

    document.body.appendChild(aDivWrp)

    // 判断有没有传位置
    if(opt.option.position.left === null || opt.option.position.right === null || opt.option.position.top === null || opt.option.position.bottom === null) {
      aDivWrp.style.top = opt.lastPostion.top ? opt.lastPostion.top : '50%'
      aDivWrp.style.right = opt.lastPostion.right ? opt.lastPostion.right : '0'
      opt.pst = 0
    } else {
      opt.pst = 1
      for(let key in opt.option.position) {
        if(opt.option.position[key] !== null) {
          aDivWrp.style[key] = (opt.option.position[key]).toString().indexOf('px') !== -1 ? opt.option.position[key] : opt.option.position[key] + 'px'
        }
      }
    }

    // 是否展示悬浮球
    if(!opt.option.showFloat) {
      aDivFloat.style.display = 'none'
      opt.isShowIframe = true
      aIfr.style.display = 'block'
      aIfr.style.right = 0
    }

    this.dragObj()  

  }

  // 插入css
  // this.addStylesheetRules = function(decls, ruleName = null) {
  //   var style = document.createElement('style');
  //   document.getElementsByTagName('head')[0].appendChild(style);
  //   if (!window.createPopup) { /* For Safari */
  //       style.appendChild(document.createTextNode(''));
  //   }
  //   var s = document.styleSheets[document.styleSheets.length - 1];
  //   if (ruleName !== null && ruleName.length > 0) {
  //       s.ruleName = ruleName;
  //   }
  //   for (var i = 0, dl = decls.length; i < dl; i++) {
  //       var j = 1, decl = decls[i], selector = decl[0], rulesStr = '';
  //       if (Object.prototype.toString.call(decl[1][0]) === '[object Array]') {
  //           decl = decl[1];
  //           j = 0;
  //       }
  //       for (var rl = decl.length; j < rl; j++) {
  //           var rule = decl[j];
  //           rulesStr += rule[0] + ':' + rule[1] + (rule[2] ? ' !important' : '') + ';\n';
  //       }

  //       if (s.insertRule) {
  //           s.insertRule(selector + '{' + rulesStr + 'content: "";' + '}', s.cssRules.length);
  //       }
  //       else { /* IE */
  //           s.addRule(selector, rulesStr, -1);
  //       }
  //   }
  // },

  this.timeChange = function (val) {
    opt.setNowTime = val
  }

  // 获取聊天模块消息
  this.getMsg = function () {
    window.addEventListener('message', function ({ data }) {
      // console.log(data)
      if (data instanceof Object) {
        for (let i in data) {
          if (opt.hasOwnProperty(i)) {
            opt[i] = data[i]
          }
        }
      } else if (typeof data == 'string') {
        eval(data)
      }
    })
  }

  // 发送信息
  this.sendMsg = function (data) {
    // console.log('%cpostMessage: ' + JSON.stringify(data), 'color: blue')

    document
      .getElementById(opt.webcallIframeId)
      .contentWindow.postMessage(data, '*')
  }

  // 提供反馈信息
  this.callbackJSON = function (handler, data) {
    data = this.isJSON(data) ? JSON.parse(data) : data
    switch (handler) {
      // 来电消息反馈
      case 'callingPopup':
        opt.option.handlerCallIn(data)
        break
      // 外呼报错反馈
      case 'calloutErr':
        opt.option.handlerCallOutErr(data)
        break
      // 挂断
      case 'hangUp':
        opt.option.handlerHangUp(data)
        break
      // 坐席接起
      case 'agentPickUp':
        opt.option.handlerAgentPickUp(data)
        break
      // 客户接起(通话中)
      case 'customerPickUp':
        opt.option.handlerCustomerPickUp(data)
        break
      // dtmf返回结果
      case 'dtmfCallback':
        opt.option.handlerDTMFCallback(data)
        break
      // 设置自动外呼结果返回
      case 'setAutoCallResult':
        opt.option.handlerAutocallCallback(data)
        break
      // 初始化完成
      case 'initResult':
        opt.option.handlerInitResult(data)
    }
  }

  // 定向路由
  this.browserRedirect = function (sUserAgent) {
    opt.turnTo = `https://webcall.izxedu.com/index.html?time=` + new Date().getTime()
    // opt.turnTo = `https://t2-webcall.izxedu.com/index.html`
    // opt.turnTo = `http://127.0.0.1:8080/index.html?time=` + new Date().getTime()
    this.setIframeSrc() 
  }

  this.changeFloatStatus = function (state) {
    opt.setFloatStatus = state
  }

  // 修改iframe大小
  this.showEquipment = function () {
    var iframe = document.getElementById(opt.webcallIframeId)
    iframe.style.height = '580px'

    // 状态回置
    if (opt.floatStatus !== 2) {
      opt.setFloatStatus = 1
    }
  }

  this.hideEquipment = function () {
    var iframe = document.getElementById(opt.webcallIframeId)
    iframe.style.height = '80px'
  }

  this.maxWin = function () {
    var iframe = document.getElementById(opt.webcallWrapperId)
    iframe.style.width = '100%'
    iframe.style.left = iframe.offsetLeft - window.innerWidth + 80 + 'px'
  }
  this.minWin = function () {
    var iframe = document.getElementById(opt.webcallWrapperId)
    iframe.style.width = '80px'
    iframe.style.left = iframe.offsetLeft + window.innerWidth - 80 + 'px'
  }

  this.dragObj = function (x, y) {
    var iframe = document.getElementById(opt.webcallWrapperId)

    var x = 0
    var y = 0
    var r = 0
    var t = 0
    opt.isDown = false
    //鼠标按下事件
    iframe.onmousedown = function (e) {
      //获取x坐标和y坐标
      x = e.clientX
      y = e.clientY

      //获取左部和顶部的偏移量
      r = window.innerWidth - iframe.offsetLeft - 80
      t = iframe.offsetTop
      //开关打开
      opt.isDown = true
      //设置样式
      iframe.style.cursor = 'move'
    }
    //鼠标移动
    window.onmousemove = function (e) {
      if (opt.isDown == false) {
        return
      }
      //获取x和y
      var nx = e.clientX
      var ny = e.clientY
      //计算移动后的左偏移量和顶部的偏移量
      var nr = x - (nx - r)
      var nt = ny - (y - t)

      if(opt.option.isDrag) {
        iframe.style.right = nr + 'px'
        iframe.style.top = nt + 'px'
      }
    }
    //鼠标抬起事件
    iframe.onmouseup = function (e) {
      var x1 = e.clientX
      var y1 = e.clientY

      var d = Math.sqrt((x1 - x) * (x1 - x) + (y1 - y) * (y1 - y))
      if (d < 7) {
        opt.setIsShowIframe = !opt.isShowIframe
      }
      //开关关闭
      opt.isDown = false
      iframe.style.cursor = 'default'
      window.localStorage.webcallIframePostion = JSON.stringify({
        top: iframe.style.top,
        right: iframe.style.right,
      })
    }
  }

  // 聊天界面加载超时判断
  this.setIframeSrc = function () {
    var iframeLoadTimeout = null
    var iframe = document.getElementById(opt.webcallIframeId)
    if (iframe.src === opt.turnTo) return
    iframe.src = opt.turnTo
    iframe.onload = function (e) {
      opt.isLoad = true

      clearTimeout(iframeLoadTimeout)

      _this.sendMsg({
        type: 'initJs',
        data: {
          ...opt.jsPms,
          pst: opt.pst,
          callNum: opt.option.callNum,
          volume: opt.option.volume,
          isBanCall: opt.option.isBanCall,
          isWebRTC: opt.option.isWebRTC,
          debug: opt.option.debug
        },
      })

      _this.sendMsg({
        type: 'initPos',
        data: {
          l: iframe.offsetLeft,
          t: iframe.offsetTop,
        },
      })
    }

    iframeLoadTimeout = setTimeout(function () {
      iframe.src = ''
    }, opt.outTime)
    clearTimeout(iframeLoadTimeout)
  }

  // 设置iframe宽度
  this.setIframeWidth = function(width) {
    document.getElementById(opt.webcallIframeId).style.width = width + 'px'
  }
  // 设置iframe高度
  this.setIframeHeight = function(height) {
    console.log('yong l me', height)
    document.getElementById(opt.webcallIframeId).style.height = height + 'px'
  }
}

