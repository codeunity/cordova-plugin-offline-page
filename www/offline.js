var offline = {
  enableOfflinePage : function () {
    cordova.exec(undefined, undefined, "HostedWebApp", "enableOfflinePage", []);
  },
  disableOfflinePage : function () {
    cordova.exec(undefined, undefined, "HostedWebApp", "disableOfflinePage", []);
  }
}

module.exports = offline;
