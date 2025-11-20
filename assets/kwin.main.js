workspace.screens.forEach(function(output) {
    output.aboutToTurnOff.connect(function() {
        // Emits a custom D-Bus signal when screen turns off
        callDBus(
            "org.kde.kwin.ScreenPower",  // Service (arbitrary name we make up)
            "/ScreenPower",              // Path
            "org.kde.kwin.ScreenPower",  // Interface
            "aboutToTurnOff",            // Method/Signal name
            output.name                  // Argument (monitor name)
        );
    });

    output.wakeUp.connect(function() {
        callDBus("org.kde.kwin.ScreenPower", "/ScreenPower", "org.kde.kwin.ScreenPower", "wakeUp", output.name);
    });
});