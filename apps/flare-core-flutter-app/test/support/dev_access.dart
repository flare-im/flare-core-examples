/// A development access config for the opt-in gateway tests: one access point
/// whose gateway WebSocket is [ws], with Core HTTP at [coreApi].
Map<String, Object?> devAccess(
  String ws, {
  String coreApi = 'http://127.0.0.1:50050',
}) => {
  'trustMode': 'development',
  'developmentEndpoints': {
    'wsUrl': ws,
    'coreApiUrl': coreApi,
    'mediaUrl': coreApi,
  },
};
