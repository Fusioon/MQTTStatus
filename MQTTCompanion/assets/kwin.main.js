const initScreenEvents = ((() => {
    
    const connectedScreens = {};
    let connectedScreenCount = 0;

    return () => {

        Object.keys(connectedScreens).forEach(v => connectedScreens[v] = false)
        
        connectedScreenCount = 0;
        workspace.screens.forEach(function(output) {
            
            connectedScreenCount++;
            if (connectedScreens.hasOwnProperty(output.name))
                return;

            connectedScreens[output.name] = true;

            output.aboutToTurnOff.connect(function() {
                callDBus("org.kde.kwin.ScreenPower", "/ScreenPower", "org.kde.kwin.ScreenPower", "aboutToTurnOff", output.name);
            });

            output.wakeUp.connect(function() {
                callDBus("org.kde.kwin.ScreenPower", "/ScreenPower", "org.kde.kwin.ScreenPower", "wakeUp", output.name);
            });
        });
        
        let prevCount = 0;
        Object.entries(connectedScreens).forEach(([k, v]) => {
            prevCount++;
            if (v === false) {
                delete connectedScreens[k];
            }
        });
    };
})());

initScreenEvents();
workspace.screensChanged.connect(initScreenEvents);