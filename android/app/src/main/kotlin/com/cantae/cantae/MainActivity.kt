package com.cantae.cantae

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service requires the launcher Activity to extend AudioServiceActivity
// (not plain FlutterActivity) so it can bind the FlutterEngine the background
// AudioService needs for lock-screen / notification transport controls
// (BG-01, BG-02). Using FlutterActivity here throws:
// "The Activity class declared in your AndroidManifest.xml is wrong or has
// not provided the correct FlutterEngine."
class MainActivity : AudioServiceActivity()
