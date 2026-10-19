import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ws/ws_client.dart';
import '../auth/auth_controller.dart';

String _reactionToEmoji(String? type) {
  switch (type) {
    case 'bicep':
      return '💪';
    case 'dumbbell':
      return '🏋️';
    default:
      return '🔥';
  }
}

String? _emojiToReaction(String? emoji) {
  switch (emoji) {
    case '💪':
      return 'bicep';
    case '🏋️':
      return 'dumbbell';
    case '🔥':
      return 'fire';
    default:
      return null;
  }
}

class ActiveUser {
  const ActiveUser({
    required this.userId,
    required this.username,
    this.status = 'online',
  });

  final String userId;
  final String username;
  final String status;
}

class FeedItem {
  const FeedItem({
    required this.userId,
    required this.username,
    required this.workoutName,
    this.workoutId,
    this.note,
    this.reactions = const {'fire': 0, 'bicep': 0, 'dumbbell': 0},
    required this.at,
  });

  final String userId;
  final String username;
  final String workoutName;
  final String? workoutId;
  final String? note;
  final Map<String, int> reactions;
  final DateTime at;

  FeedItem copyWith({Map<String, int>? reactions}) {
    return FeedItem(
      userId: userId,
      username: username,
      workoutName: workoutName,
      workoutId: workoutId,
      note: note,
      reactions: reactions ?? this.reactions,
      at: at,
    );
  }
}

class CheerEvent {
  const CheerEvent({required this.fromUsername, required this.emoji});

  final String fromUsername;
  final String emoji;
}

class CommunityState {
  const CommunityState({
    this.activeUsers = const [],
    this.feed = const [],
    this.lastCheer,
    this.connected = false,
  });

  final List<ActiveUser> activeUsers;
  final List<FeedItem> feed;
  final CheerEvent? lastCheer;
  final bool connected;

  CommunityState copyWith({
    List<ActiveUser>? activeUsers,
    List<FeedItem>? feed,
    CheerEvent? lastCheer,
    bool clearCheer = false,
    bool? connected,
  }) {
    return CommunityState(
      activeUsers: activeUsers ?? this.activeUsers,
      feed: feed ?? this.feed,
      lastCheer: clearCheer ? null : (lastCheer ?? this.lastCheer),
      connected: connected ?? this.connected,
    );
  }
}

final communityProvider = NotifierProvider<CommunityController, CommunityState>(
  CommunityController.new,
);

class CommunityController extends Notifier<CommunityState> {
  static const _maxFeed = 50;
  static const _maxUsers = 30;

  WsClient? _ws;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _reconnectTimer;
  String? _myUserId;

  @override
  CommunityState build() {
    final auth = ref.watch(authControllerProvider);
    _myUserId = auth.user?.id;

    if (auth.token == null) {
      _teardown();
      return const CommunityState();
    }
    if (_ws == null) {
      _connect(auth.token!);
    }
    return state;
  }

  void _connect(String token) {
    _teardown();
    state = const CommunityState();
    final client = WsClient();
    client.connect(token: token);
    _ws = client;
    _subscription = client.messages.listen(
      _onMessage,
      onError: (Object _) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
    );
    client.send({'type': 'presence', 'status': 'online'});
    state = state.copyWith(connected: true);
  }

  void _teardown() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _ws?.close();
    _ws = null;
  }

  void _scheduleReconnect() {
    if (_ws == null) return;
    _ws = null;
    state = state.copyWith(connected: false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      final token = ref.read(authControllerProvider).token;
      if (token != null) {
        _connect(token);
      }
    });
  }

  void _onMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'presence':
        _onPresence(message);
        break;
      case 'feed_update':
        _onFeedUpdate(message);
        break;
      case 'live_cheer':
        _onLiveCheer(message);
        break;
    }
  }

  void _onPresence(Map<String, dynamic> message) {
    final userId = message['user_id'] as String?;
    final username = (message['username'] as String?) ?? 'Usuario';
    final status = (message['status'] as String?) ?? 'online';
    if (userId == null || userId == _myUserId) return;

    final existingIndex =
        state.activeUsers.indexWhere((u) => u.userId == userId);
    final user = ActiveUser(
      userId: userId,
      username: username,
      status: status,
    );

    final List<ActiveUser> users;
    if (existingIndex >= 0) {
      users = List.of(state.activeUsers)..[existingIndex] = user;
    } else {
      users = [...state.activeUsers, user];
    }

    state = state.copyWith(
      activeUsers: users.length > _maxUsers
          ? users.sublist(users.length - _maxUsers)
          : users,
    );
  }

  void _onFeedUpdate(Map<String, dynamic> message) {
    final from = message['from'] as String?;
    final username = (message['from_username'] as String?) ?? 'Usuario';
    final data = message['data'] as Map<String, dynamic>? ?? const {};
    final workoutName = data['workout_name'] as String? ?? 'un entrenamiento';
    if (from == null) return;
    final at =
        DateTime.tryParse(message['at'] as String? ?? '') ?? DateTime.now();
    final reactions = _parseReactions(data['reactions']);
    final item = FeedItem(
      userId: from,
      username: username,
      workoutName: workoutName,
      workoutId: data['workout_id'] as String?,
      note: data['note'] as String?,
      reactions: reactions,
      at: at,
    );
    final feed = [item, ...state.feed];
    state = state.copyWith(
      feed: feed.length > _maxFeed ? feed.sublist(0, _maxFeed) : feed,
    );
  }

  Map<String, int> _parseReactions(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return {
        'fire': (raw['fire'] as num?)?.toInt() ?? 0,
        'bicep': (raw['bicep'] as num?)?.toInt() ?? 0,
        'dumbbell': (raw['dumbbell'] as num?)?.toInt() ?? 0,
      };
    }
    return const {'fire': 0, 'bicep': 0, 'dumbbell': 0};
  }

  void _onLiveCheer(Map<String, dynamic> message) {
    final data = message['data'] as Map<String, dynamic>? ?? const {};
    final workoutId = data['workout_id'] as String?;
    String? reactionType = data['reaction_type'] as String?;
    final emojiRaw = data['emoji'] as String?;
    if (reactionType == null && emojiRaw != null) {
      reactionType = _emojiToReaction(emojiRaw);
    }
    final effectiveEmoji = emojiRaw ?? _reactionToEmoji(reactionType);
    if (workoutId != null && reactionType != null) {
      final type = reactionType;
      final feed = state.feed.map((item) {
        if (item.workoutId == workoutId) {
          final reactions = data['reactions'] as Map<String, dynamic>?;
          final updatedReactions = reactions != null
              ? _parseReactions(reactions)
              : {
                  ...item.reactions,
                  type: (item.reactions[type] ?? 0) + 1,
                };
          return item.copyWith(reactions: updatedReactions);
        }
        return item;
      }).toList();
      state = state.copyWith(feed: feed);
    }
    final targetId =
        data['to_user_id'] as String? ?? data['to_user'] as String?;
    if (targetId != _myUserId) return;
    final fromUsername = (message['from_username'] as String?) ?? 'Alguien';
    state = state.copyWith(
      lastCheer: CheerEvent(
        fromUsername: fromUsername,
        emoji: effectiveEmoji,
      ),
    );
  }

  void updatePresence(String status) {
    _ws?.send({
      'type': 'presence',
      'status': status,
    });
  }

  void postWorkout(String workoutName, {String? workoutId, String? note}) {
    _ws?.send({
      'type': 'feed_update',
      'data': {
        'workout_name': workoutName,
        'workout_id': ?workoutId,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    });
  }

  void cheer(
    String targetUserId, {
    String? workoutId,
    String reactionType = 'fire',
  }) {
    final emoji = _reactionToEmoji(reactionType);
    _ws?.send({
      'type': 'live_cheer',
      'data': {
        'to_user_id': targetUserId,
        'to_user': targetUserId,
        'workout_id': ?workoutId,
        'reaction_type': reactionType,
        'emoji': emoji,
      },
    });
  }
}
