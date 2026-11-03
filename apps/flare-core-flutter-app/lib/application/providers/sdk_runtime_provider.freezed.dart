// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sdk_runtime_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SdkRuntimeSnapshot {
  bool get loading => throw _privateConstructorUsedError;
  Map<String, Object?> get diagnostics => throw _privateConstructorUsedError;
  Map<String, Object?> get capabilities => throw _privateConstructorUsedError;
  Map<String, Object?> get userCapabilities =>
      throw _privateConstructorUsedError;
  Map<String, Object?> get mediaCache => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of SdkRuntimeSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SdkRuntimeSnapshotCopyWith<SdkRuntimeSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SdkRuntimeSnapshotCopyWith<$Res> {
  factory $SdkRuntimeSnapshotCopyWith(
    SdkRuntimeSnapshot value,
    $Res Function(SdkRuntimeSnapshot) then,
  ) = _$SdkRuntimeSnapshotCopyWithImpl<$Res, SdkRuntimeSnapshot>;
  @useResult
  $Res call({
    bool loading,
    Map<String, Object?> diagnostics,
    Map<String, Object?> capabilities,
    Map<String, Object?> userCapabilities,
    Map<String, Object?> mediaCache,
    String? error,
  });
}

/// @nodoc
class _$SdkRuntimeSnapshotCopyWithImpl<$Res, $Val extends SdkRuntimeSnapshot>
    implements $SdkRuntimeSnapshotCopyWith<$Res> {
  _$SdkRuntimeSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SdkRuntimeSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loading = null,
    Object? diagnostics = null,
    Object? capabilities = null,
    Object? userCapabilities = null,
    Object? mediaCache = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            loading: null == loading
                ? _value.loading
                : loading // ignore: cast_nullable_to_non_nullable
                      as bool,
            diagnostics: null == diagnostics
                ? _value.diagnostics
                : diagnostics // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            capabilities: null == capabilities
                ? _value.capabilities
                : capabilities // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            userCapabilities: null == userCapabilities
                ? _value.userCapabilities
                : userCapabilities // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            mediaCache: null == mediaCache
                ? _value.mediaCache
                : mediaCache // ignore: cast_nullable_to_non_nullable
                      as Map<String, Object?>,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SdkRuntimeSnapshotImplCopyWith<$Res>
    implements $SdkRuntimeSnapshotCopyWith<$Res> {
  factory _$$SdkRuntimeSnapshotImplCopyWith(
    _$SdkRuntimeSnapshotImpl value,
    $Res Function(_$SdkRuntimeSnapshotImpl) then,
  ) = __$$SdkRuntimeSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool loading,
    Map<String, Object?> diagnostics,
    Map<String, Object?> capabilities,
    Map<String, Object?> userCapabilities,
    Map<String, Object?> mediaCache,
    String? error,
  });
}

/// @nodoc
class __$$SdkRuntimeSnapshotImplCopyWithImpl<$Res>
    extends _$SdkRuntimeSnapshotCopyWithImpl<$Res, _$SdkRuntimeSnapshotImpl>
    implements _$$SdkRuntimeSnapshotImplCopyWith<$Res> {
  __$$SdkRuntimeSnapshotImplCopyWithImpl(
    _$SdkRuntimeSnapshotImpl _value,
    $Res Function(_$SdkRuntimeSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SdkRuntimeSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loading = null,
    Object? diagnostics = null,
    Object? capabilities = null,
    Object? userCapabilities = null,
    Object? mediaCache = null,
    Object? error = freezed,
  }) {
    return _then(
      _$SdkRuntimeSnapshotImpl(
        loading: null == loading
            ? _value.loading
            : loading // ignore: cast_nullable_to_non_nullable
                  as bool,
        diagnostics: null == diagnostics
            ? _value._diagnostics
            : diagnostics // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        capabilities: null == capabilities
            ? _value._capabilities
            : capabilities // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        userCapabilities: null == userCapabilities
            ? _value._userCapabilities
            : userCapabilities // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        mediaCache: null == mediaCache
            ? _value._mediaCache
            : mediaCache // ignore: cast_nullable_to_non_nullable
                  as Map<String, Object?>,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$SdkRuntimeSnapshotImpl implements _SdkRuntimeSnapshot {
  const _$SdkRuntimeSnapshotImpl({
    this.loading = false,
    final Map<String, Object?> diagnostics = const <String, Object?>{},
    final Map<String, Object?> capabilities = const <String, Object?>{},
    final Map<String, Object?> userCapabilities = const <String, Object?>{},
    final Map<String, Object?> mediaCache = const <String, Object?>{},
    this.error,
  }) : _diagnostics = diagnostics,
       _capabilities = capabilities,
       _userCapabilities = userCapabilities,
       _mediaCache = mediaCache;

  @override
  @JsonKey()
  final bool loading;
  final Map<String, Object?> _diagnostics;
  @override
  @JsonKey()
  Map<String, Object?> get diagnostics {
    if (_diagnostics is EqualUnmodifiableMapView) return _diagnostics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_diagnostics);
  }

  final Map<String, Object?> _capabilities;
  @override
  @JsonKey()
  Map<String, Object?> get capabilities {
    if (_capabilities is EqualUnmodifiableMapView) return _capabilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_capabilities);
  }

  final Map<String, Object?> _userCapabilities;
  @override
  @JsonKey()
  Map<String, Object?> get userCapabilities {
    if (_userCapabilities is EqualUnmodifiableMapView) return _userCapabilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_userCapabilities);
  }

  final Map<String, Object?> _mediaCache;
  @override
  @JsonKey()
  Map<String, Object?> get mediaCache {
    if (_mediaCache is EqualUnmodifiableMapView) return _mediaCache;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_mediaCache);
  }

  @override
  final String? error;

  @override
  String toString() {
    return 'SdkRuntimeSnapshot(loading: $loading, diagnostics: $diagnostics, capabilities: $capabilities, userCapabilities: $userCapabilities, mediaCache: $mediaCache, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SdkRuntimeSnapshotImpl &&
            (identical(other.loading, loading) || other.loading == loading) &&
            const DeepCollectionEquality().equals(
              other._diagnostics,
              _diagnostics,
            ) &&
            const DeepCollectionEquality().equals(
              other._capabilities,
              _capabilities,
            ) &&
            const DeepCollectionEquality().equals(
              other._userCapabilities,
              _userCapabilities,
            ) &&
            const DeepCollectionEquality().equals(
              other._mediaCache,
              _mediaCache,
            ) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    loading,
    const DeepCollectionEquality().hash(_diagnostics),
    const DeepCollectionEquality().hash(_capabilities),
    const DeepCollectionEquality().hash(_userCapabilities),
    const DeepCollectionEquality().hash(_mediaCache),
    error,
  );

  /// Create a copy of SdkRuntimeSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SdkRuntimeSnapshotImplCopyWith<_$SdkRuntimeSnapshotImpl> get copyWith =>
      __$$SdkRuntimeSnapshotImplCopyWithImpl<_$SdkRuntimeSnapshotImpl>(
        this,
        _$identity,
      );
}

abstract class _SdkRuntimeSnapshot implements SdkRuntimeSnapshot {
  const factory _SdkRuntimeSnapshot({
    final bool loading,
    final Map<String, Object?> diagnostics,
    final Map<String, Object?> capabilities,
    final Map<String, Object?> userCapabilities,
    final Map<String, Object?> mediaCache,
    final String? error,
  }) = _$SdkRuntimeSnapshotImpl;

  @override
  bool get loading;
  @override
  Map<String, Object?> get diagnostics;
  @override
  Map<String, Object?> get capabilities;
  @override
  Map<String, Object?> get userCapabilities;
  @override
  Map<String, Object?> get mediaCache;
  @override
  String? get error;

  /// Create a copy of SdkRuntimeSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SdkRuntimeSnapshotImplCopyWith<_$SdkRuntimeSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
