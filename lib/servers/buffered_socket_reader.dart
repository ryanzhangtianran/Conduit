import 'dart:async';
import 'dart:typed_data';

/// Owns the single subscription on a byte stream during a handshake.
///
/// Incoming bytes are buffered and served to sequential [read] / [readUntil]
/// calls. Once the handshake is over, [startPump] switches to forwarding:
/// any buffered overshoot is replayed into [stream] first and later bytes
/// flow straight through, so a tunnel can be built on top of the same
/// subscription without re-listening to the socket.
class BufferedSocketReader {
  BufferedSocketReader(Stream<List<int>> input, {required this.closedError}) {
    _subscription = input.listen(
      _onData,
      onError: _controller.addError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  /// Builds the exception thrown when the peer closes the connection while
  /// a read is still waiting for bytes.
  final Object Function() closedError;
  final _buffer = BytesBuilder(copy: false);
  final _controller = StreamController<Uint8List>();
  StreamSubscription<List<int>>? _subscription;
  Completer<void>? _wake;
  bool _closed = false;
  bool _pumping = false;

  /// Bytes arriving after [startPump].
  Stream<Uint8List> get stream => _controller.stream;

  void _onData(List<int> chunk) {
    if (_pumping) {
      _controller.add(Uint8List.fromList(chunk));
    } else {
      _buffer.add(chunk);
      _completeWake();
    }
  }

  void _onDone() {
    _closed = true;
    _completeWake();
    // Closing before anyone listens to [stream] is harmless and makes a
    // tunnel whose peer drops right after the handshake fail fast. Without a
    // listener the returned future never completes, so it is never awaited.
    unawaited(_controller.close());
  }

  void _completeWake() {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  Future<void> _waitForBytes(Duration timeout) async {
    if (_closed) throw closedError();
    final wake = _wake = Completer<void>();
    await wake.future.timeout(timeout);
  }

  /// Reads exactly [count] bytes, waiting up to [timeout] for each chunk.
  Future<Uint8List> read(int count, Duration timeout) async {
    while (_buffer.length < count) {
      await _waitForBytes(timeout);
    }
    return _take(count);
  }

  /// Reads up to and including the first occurrence of [marker].
  Future<Uint8List> readUntil(List<int> marker, Duration timeout) async {
    while (_indexOf(_buffer.toBytes(), marker) == null) {
      await _waitForBytes(timeout);
    }
    return _take(_indexOf(_buffer.toBytes(), marker)! + marker.length);
  }

  Uint8List _take(int count) {
    final bytes = _buffer.takeBytes();
    final result = Uint8List.fromList(bytes.sublist(0, count));
    if (bytes.length > count) _buffer.add(bytes.sublist(count));
    return result;
  }

  /// Switches from buffering to forwarding. Any bytes buffered beyond the
  /// handshake are replayed into [stream].
  void startPump() {
    _pumping = true;
    final leftover = _buffer.takeBytes();
    if (leftover.isNotEmpty) _controller.add(Uint8List.fromList(leftover));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  static int? _indexOf(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return null;
  }
}
