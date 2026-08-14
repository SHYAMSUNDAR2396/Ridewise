/**
 * @format
 */

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);

import TrackPlayer from "react-native-track-player";
TrackPlayer.registerPlaybackService(() => require("./src/features/capsules/playback-service"));
