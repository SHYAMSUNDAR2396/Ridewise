// Native modules with no software fallback in the Jest (jsdom-less, no
// simulator) environment. Mocked globally so every test file -- including
// App.test.tsx's full-tree smoke render -- can import screens that reach
// these modules without a real native binding. Individual test files may
// still call jest.mock(...) themselves to override specific return values;
// a later per-file jest.mock call wins over this default.
jest.mock("react-native-track-player", () => ({
  __esModule: true,
  default: {
    setupPlayer: jest.fn().mockResolvedValue(undefined),
    registerPlaybackService: jest.fn(),
    addEventListener: jest.fn(() => ({ remove: jest.fn() })),
    add: jest.fn().mockResolvedValue(undefined),
    setQueue: jest.fn().mockResolvedValue(undefined),
    skip: jest.fn().mockResolvedValue(undefined),
    seekTo: jest.fn().mockResolvedValue(undefined),
    seekBy: jest.fn().mockResolvedValue(undefined),
    play: jest.fn().mockResolvedValue(undefined),
    pause: jest.fn().mockResolvedValue(undefined),
    reset: jest.fn().mockResolvedValue(undefined),
    updateOptions: jest.fn().mockResolvedValue(undefined),
    getActiveTrack: jest.fn().mockResolvedValue(undefined),
    getPlaybackState: jest.fn().mockResolvedValue({ state: "none" }),
    getProgress: jest.fn().mockResolvedValue({ position: 0, duration: 0, buffered: 0 }),
  },
  Event: {
    RemotePlay: "remote-play",
    RemotePause: "remote-pause",
    RemoteSeek: "remote-seek",
    PlaybackState: "playback-state",
    PlaybackActiveTrackChanged: "playback-active-track-changed",
  },
  State: {
    None: "none",
    Ready: "ready",
    Playing: "playing",
    Paused: "paused",
    Stopped: "stopped",
    Loading: "loading",
    Buffering: "buffering",
    Error: "error",
    Ended: "ended",
  },
  useActiveTrack: () => undefined,
  usePlaybackState: () => ({ state: "none" }),
  useProgress: () => ({ position: 0, duration: 0, buffered: 0 }),
}));

jest.mock("react-native-blob-util", () => ({
  __esModule: true,
  default: {
    fs: {
      dirs: { DocumentDir: "/mock/documents" },
      exists: jest.fn().mockResolvedValue(true),
      unlink: jest.fn().mockResolvedValue(undefined),
    },
    config: () => ({ fetch: jest.fn().mockResolvedValue({}) }),
  },
}));
