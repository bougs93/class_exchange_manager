import '../models/exchange_history_item.dart';
import '../models/exchange_path.dart';
import '../models/one_to_one_exchange_path.dart';
import '../models/circular_exchange_path.dart';
import '../models/dual_exchange_path.dart';
import '../models/supplement_exchange_path.dart';
import '../utils/day_utils.dart';
import '../utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'exchange_list_storage_service.dart';
import 'dart:developer' as developer;

/// 교체 히스토리를 관리하는 서비스 클래스
/// 교체 실행, 되돌리기, 교체 리스트 관리를 담당
class ExchangeHistoryService {
  // 싱글톤 인스턴스
  static final ExchangeHistoryService _instance =
      ExchangeHistoryService._internal();

  // 싱글톤 생성자
  factory ExchangeHistoryService() => _instance;

  // 내부 생성자
  ExchangeHistoryService._internal();

  // 되돌리기용 스택 (메모리 저장, 최근 10개)
  final List<ExchangeHistoryItem> _undoStack = [];

  // 다시 실행용 스택 (되돌리기 후 1단계씩 복구)
  final List<ExchangeHistoryItem> _redoStack = [];

  // 교체 리스트용 아카이브 (로컬 저장소, 모든 교체 보관)
  final List<ExchangeHistoryItem> _exchangeList = [];

  // 교체된 셀 관리는 _exchangeList를 통해 직접 확인

  // 최대 되돌리기 항목 수
  static const int maxUndoItems = 10;

  // 교체 리스트 변경 추적을 위한 버전 카운터
  // 이 값이 변경되면 교체 리스트가 변경된 것으로 간주합니다.
  int _exchangeListVersion = 0;

  /// 현재 스코프 시간표 ID
  ///
  /// null이면 교체 리스트 저장/로드가 건너뛰어집니다 (스코프 필수 정책).
  /// 활성 시간표 전환 시 Provider 계층에서 설정하고 재로드합니다.
  String? timetableId;

  // 버전 변경 콜백 (외부에서 설정하여 버전 변경 시 알림을 받을 수 있음)
  void Function()? _onVersionChanged;

  /// 교체 리스트가 JSON에 저장될 때마다 SQLite 저널에도 같은 내용을
  /// 미러링하는 보조 싱크 (S5.1).
  ///
  /// 기본값 null — 주입하지 않으면 이 서비스의 동작은 S5.0 이전과
  /// 완전히 동일하다. **JSON이 여전히 진실 원본**이다: 이 싱크가 예외를
  /// 던지거나 실패해도 `_enqueueStorageOperation`이 잡아 로그만 남기고
  /// JSON 저장에는 전혀 영향을 주지 않는다(같은 저장 큐에서 순서만
  /// 보장한다). Provider 계층(`services_provider.dart`)에서 주입한다.
  Future<void> Function(List<ExchangeHistoryItem> items, String timetableId)?
  mirrorSink;

  /// 교체 리스트 전체 삭제 시 SQLite 저널도 함께 비우는 보조 싱크 (S5.1).
  ///
  /// [mirrorSink]와 마찬가지로 기본값 null, 실패해도 JSON 삭제에 영향 없음.
  Future<void> Function(String timetableId)? mirrorClearSink;

  /// SQLite `exchange_events` 저널에서 이 시간표의 교체 이력을 읽어오는
  /// 보조 싱크 (S5.4b — "여기서부터 신규가 진실 원본").
  ///
  /// [loadFromLocalStorage]가 이 싱크로 먼저 SQLite를 확인하고, **결과가
  /// 있으면 그것을 그대로 진실 원본으로 쓴다** — JSON은 더 이상 읽지 않는다.
  /// SQLite에 아직 아무것도 없으면(이 시간표를 아직 한 번도 이관하지 않음)
  /// 기존 JSON 경로로 그대로 폴백하고, 그 결과를 [mirrorSink]로 SQLite에
  /// 최초 1회 이관한다(S5.1 보완 로직 재사용 — 새 코드 경로를 만들지 않음).
  /// 이 싱크가 예외를 던지면 로그만 남기고 JSON 경로로 폴백한다.
  Future<List<ExchangeHistoryItem>> Function(String timetableId)? loadSink;

  /// 직전 로드에서 구 스키마(§10 이전) 교체 목록을 발견해 백업했는지 여부.
  ///
  /// true면 사용자에게 1회 안내가 필요하다 — "이전 버전의 교체 목록은
  /// 날짜 정보가 없어 사용할 수 없습니다. (`*.v1.bak`으로 보관됨)".
  /// [consumeLegacyDataNotice]로 소비하면 false로 리셋된다 (같은 세션에서
  /// 중복 안내 방지).
  bool _legacyDataBackedUp = false;

  /// 구 데이터 백업 안내를 소비한다 — 호출 시점의 값을 반환하고 false로 리셋.
  bool consumeLegacyDataNotice() {
    final value = _legacyDataBackedUp;
    _legacyDataBackedUp = false;
    return value;
  }

  /// 버전 변경 콜백 설정 (Provider에서 호출)
  void setVersionChangedCallback(void Function()? callback) {
    _onVersionChanged = callback;
  }

  /// 버전 변경 알림 (내부 메서드)
  void _notifyVersionChanged() {
    if (_onVersionChanged != null) {
      _onVersionChanged!();
    }
  }

  /// 교체 실행 및 히스토리에 추가 (통합 메서드)
  /// 교체 버튼 클릭 시 호출
  ///
  /// [absenceDate]/[substitutionDate]는 필수다 — 호출부가 "지금 보고 있는 주"를
  /// 기준으로 실행 이전에 확정해서 넘긴다(§10.4). 이 서비스는 날짜를 추정하지 않는다.
  void executeExchange(
    ExchangePath path, {
    required DateTime absenceDate,
    required DateTime substitutionDate,
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
    int? stepCount, // 순환교체 단계 수 (선택적)
    Map<String, DateTime>? nodeDates, // 순환·2중 노드별 확정 날짜 (S5.6.7, 선택적)
  }) {
    // 실제 교체 실행 (TimetableDataSource 업데이트는 외부에서 처리)
    AppLogger.exchangeInfo('[교체 실행] ${path.displayTitle}');

    // 히스토리에 추가
    addExchange(
      path,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      customDescription: customDescription,
      additionalMetadata: additionalMetadata,
      notes: notes,
      tags: tags,
      stepCount: stepCount,
      nodeDates: nodeDates,
    );
  }

  /// 교체 실행 시 히스토리에 추가 (내부 메서드)
  void addExchange(
    ExchangePath path, {
    required DateTime absenceDate,
    required DateTime substitutionDate,
    String? customDescription,
    Map<String, dynamic>? additionalMetadata,
    String? notes,
    List<String>? tags,
    int? stepCount, // 순환교체 단계 수 (선택적)
    Map<String, DateTime>? nodeDates, // 순환·2중 노드별 확정 날짜 (S5.6.7, 선택적)
  }) {
    // ExchangeHistoryItem 생성
    final item = ExchangeHistoryItem.fromExchangePath(
      path,
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
      customDescription: customDescription,
      additionalMetadata: additionalMetadata,
      notes: notes,
      tags: tags,
      stepCount: stepCount,
      nodeDates: nodeDates,
    );

    // 교체 리스트에 추가 (영구 보관)
    _exchangeList.add(item);
    _saveToLocalStorage(item);

    // 🔥 교체 리스트 변경 추적: 버전 증가
    _exchangeListVersion++;
    _notifyVersionChanged();

    // 되돌리기 스택에 추가 (최근 10개만)
    _undoStack.add(item);
    if (_undoStack.length > maxUndoItems) {
      _undoStack.removeAt(0);
      // 메모리에서만 제거, 로컬 저장소는 유지
    }

    // 새 교체 실행 시 다시 실행 스택 초기화 (표준 undo/redo 동작)
    _redoStack.clear();
  }

  /// 교체 리스트에서 특정 항목 삭제
  /// 삭제 버튼 클릭 시 호출
  void removeFromExchangeList(String itemId) {
    _exchangeList.removeWhere((item) => item.id == itemId);
    _purgeItemFromStacks(itemId);

    _removeFromLocalStorage(itemId);

    _exchangeListVersion++;
    _notifyVersionChanged();
  }

  /// 교체 리스트 전체 조회
  List<ExchangeHistoryItem> getExchangeList() {
    return List.from(_exchangeList);
  }

  /// 활성(되돌리지 않은) 교체 리스트 조회
  List<ExchangeHistoryItem> getActiveExchangeList() {
    return _exchangeList.where((item) => !item.isReverted).toList();
  }

  /// 교체 리스트 버전 조회 (변경 추적용)
  /// 이 값이 변경되면 교체 리스트가 변경된 것으로 간주됩니다.
  int getExchangeListVersion() {
    return _exchangeListVersion;
  }

  /// 다른 PC에서 내보낸 결보강 내역을 가져와 반영한다.
  ///
  /// [overwrite]가 true면 기존 목록을 모두 지우고 [items]로 교체한다
  /// (날짜 충돌이 있어 사용자가 "지우고 가져오기"를 확정한 경우).
  /// false면 기존 목록 뒤에 [items]를 추가한다(충돌 없는 병합).
  /// 되돌리기 스택은 항상 초기화한다 — 가져온 항목은 이 세션에서 실행한
  /// 조작이 아니므로 되돌리기 대상이 아니다.
  void importExchangeItems(
    List<ExchangeHistoryItem> items, {
    required bool overwrite,
  }) {
    if (overwrite) {
      _exchangeList.clear();
    }
    _exchangeList.addAll(items);
    _undoStack.clear();
    _redoStack.clear();

    _exchangeListVersion++;
    _notifyVersionChanged();
    _enqueueExchangeListSave('가져온 결보강 내역 저장 실패');
  }

  /// 교체 리스트 전체 삭제
  void clearExchangeList() {
    _exchangeList.clear();
    _undoStack.clear();
    _redoStack.clear();
    _clearLocalStorage();

    // 🔥 교체 리스트 변경 추적: 버전 증가
    _exchangeListVersion++;
    _notifyVersionChanged();
  }

  /// 되돌리기 스택 조회
  List<ExchangeHistoryItem> getUndoStack() {
    return List.from(_undoStack);
  }

  /// 되돌리기 가능 여부
  bool get canUndo => _undoStack.isNotEmpty;

  /// 다시 실행 가능 여부 (되돌리기 직후에만)
  bool get canRedo => _redoStack.isNotEmpty;

  /// 다시 실행 스택 조회
  List<ExchangeHistoryItem> getRedoStack() {
    return List.from(_redoStack);
  }

  /// 가장 최근 교체 작업 되돌리기
  /// 되돌리기 버튼 클릭 시 호출
  ExchangeHistoryItem? undoLastExchange() {
    if (_undoStack.isEmpty) return null;

    final item = _undoStack.removeLast();

    final index = _exchangeList.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      _undoStack.add(item);
      return null;
    }

    // 되돌리기 상태로 변경 (리스트에서 제거하지 않음 → 다시 실행 가능)
    final revertedItem = item.copyWithReverted(true);
    _exchangeList[index] = revertedItem;
    _updateInLocalStorage(revertedItem);

    _exchangeListVersion++;
    _notifyVersionChanged();

    // 다시 실행 스택에 추가
    _redoStack.add(item);

    return item;
  }

  /// 되돌리기한 교체 1건 다시 실행
  /// 다시 실행 버튼 클릭 시 호출
  ExchangeHistoryItem? redoLastExchange() {
    if (_redoStack.isEmpty) return null;

    final item = _redoStack.removeLast();

    final index = _exchangeList.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      _redoStack.add(item);
      return null;
    }

    // 활성 상태로 복구
    final restoredItem = item.copyWithReverted(false);
    _exchangeList[index] = restoredItem;
    _updateInLocalStorage(restoredItem);

    // 되돌리기 스택에 다시 추가
    _undoStack.add(item);
    if (_undoStack.length > maxUndoItems) {
      _undoStack.removeAt(0);
    }

    _exchangeListVersion++;
    _notifyVersionChanged();

    return restoredItem;
  }

  /// 되돌리기 스택 초기화
  void clearUndoStack() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// undo/redo 스택에서 특정 항목 제거
  void _purgeItemFromStacks(String itemId) {
    _undoStack.removeWhere((item) => item.id == itemId);
    _redoStack.removeWhere((item) => item.id == itemId);
  }

  /// 단위 테스트용 상태 초기화 (로컬 저장소 I/O 없음)
  @visibleForTesting
  void resetForTesting() {
    _exchangeList.clear();
    _undoStack.clear();
    _redoStack.clear();
    _exchangeListVersion = 0;
    _legacyDataBackedUp = false;
    // 싱글톤이라 다른 테스트(Provider 트리를 빌드한 위젯 테스트 등)가 미리
    // 주입해 둔 싱크가 남아있을 수 있다 — 여기서 확실히 비운다(S5.1).
    mirrorSink = null;
    mirrorClearSink = null;
    loadSink = null;
  }

  /// 교체 리스트에서 특정 항목 조회
  ExchangeHistoryItem? getExchangeItem(String itemId) {
    try {
      return _exchangeList.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  /// 교체 리스트에서 설명으로 검색
  List<ExchangeHistoryItem> searchByDescription(String query) {
    if (query.isEmpty) return getExchangeList();

    return _exchangeList
        .where(
          (item) =>
              item.description.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  /// 교체 리스트에서 날짜별 필터링
  List<ExchangeHistoryItem> filterByDate(DateTime start, DateTime end) {
    return _exchangeList
        .where(
          (item) =>
              item.timestamp.isAfter(start) && item.timestamp.isBefore(end),
        )
        .toList();
  }

  /// 교체 리스트에서 타입별 필터링
  List<ExchangeHistoryItem> filterByType(ExchangePathType type) {
    return _exchangeList.where((item) => item.type == type).toList();
  }

  /// 교체 리스트에서 태그별 필터링
  List<ExchangeHistoryItem> filterByTags(List<String> tags) {
    return _exchangeList
        .where((item) => tags.any((tag) => item.tags.contains(tag)))
        .toList();
  }

  /// 교체 리스트 항목 수정 (메모, 태그)
  void updateExchangeItem(
    String itemId, {
    String? notes,
    List<String>? tags,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final index = _exchangeList.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    ExchangeHistoryItem updatedItem = _exchangeList[index];

    if (notes != null) {
      updatedItem = updatedItem.copyWithNotes(notes);
    }

    if (tags != null) {
      updatedItem = updatedItem.copyWithTags(tags);
    }

    if (additionalMetadata != null) {
      updatedItem = updatedItem.copyWithMetadata(additionalMetadata);
    }

    _exchangeList[index] = updatedItem;
    _updateInLocalStorage(updatedItem);
  }

  /// 교체 리스트 통계 정보
  Map<String, dynamic> getExchangeListStats() {
    final total = _exchangeList.length;
    final reverted = _exchangeList.where((item) => item.isReverted).length;
    final active = total - reverted;

    final typeStats = <ExchangePathType, int>{};
    for (final item in _exchangeList) {
      typeStats[item.type] = (typeStats[item.type] ?? 0) + 1;
    }

    return {
      'total': total,
      'active': active,
      'reverted': reverted,
      'typeStats': typeStats,
      'lastExchange':
          _exchangeList.isNotEmpty ? _exchangeList.last.timestamp : null,
    };
  }

  // ========== 로컬 저장소 관련 메서드들 ==========

  // 교체 리스트 저장 서비스
  final ExchangeListStorageService _storageService =
      ExchangeListStorageService();

  // Serialize file mutations. The public history API is synchronous, and
  // overlapping unawaited writes can otherwise race on Windows.
  Future<void> _storageQueue = Future<void>.value();

  Future<void> _enqueueStorageOperation(
    Future<void> Function() operation,
    String errorMessage,
  ) {
    _storageQueue = _storageQueue.then((_) => operation()).catchError((error) {
      AppLogger.error('$errorMessage: $error', error);
    });
    return _storageQueue;
  }

  void _enqueueExchangeListSave(String errorMessage) {
    final snapshot = List<ExchangeHistoryItem>.from(_exchangeList);
    final scopedTimetableId = timetableId;
    _enqueueStorageOperation(
      () => _storageService.saveExchangeList(
        snapshot,
        timetableId: scopedTimetableId,
      ),
      errorMessage,
    );

    // S5.1: JSON 저장 직후 같은 큐에 SQLite 미러 쓰기를 추가한다. JSON
    // 저장과 순서는 보장되지만, 실패해도(sink==null 포함) JSON 경로에는
    // 아무 영향이 없다 — 부가 기록일 뿐이다.
    final sink = mirrorSink;
    if (sink != null && scopedTimetableId != null) {
      _enqueueStorageOperation(
        () => sink(snapshot, scopedTimetableId),
        '교체 이벤트 SQLite 미러 저장 실패',
      );
    }
  }

  /// 교체 항목을 로컬 저장소에 저장
  ///
  /// 교체 리스트 전체를 다시 저장합니다.
  void _saveToLocalStorage(ExchangeHistoryItem item) {
    _enqueueExchangeListSave('교체 항목 저장 실패');
  }

  /// 교체 항목을 로컬 저장소에서 삭제
  ///
  /// 교체 리스트 전체를 다시 저장합니다.
  void _removeFromLocalStorage(String itemId) {
    _enqueueExchangeListSave('교체 항목 삭제 저장 실패');
  }

  /// 교체 항목을 로컬 저장소에서 업데이트
  ///
  /// 교체 리스트 전체를 다시 저장합니다.
  void _updateInLocalStorage(ExchangeHistoryItem item) {
    _enqueueExchangeListSave('교체 항목 업데이트 저장 실패');
  }

  /// 로컬 저장소에서 교체 리스트 전체 삭제
  void _clearLocalStorage() {
    final scopedTimetableId = timetableId;
    _enqueueStorageOperation(
      () => _storageService.clearExchangeList(timetableId: scopedTimetableId),
      '교체 리스트 삭제 실패',
    );

    // S5.1: JSON과 함께 SQLite 저널 미러도 비운다.
    final clearSink = mirrorClearSink;
    if (clearSink != null && scopedTimetableId != null) {
      _enqueueStorageOperation(
        () => clearSink(scopedTimetableId),
        '교체 이벤트 SQLite 미러 삭제 실패',
      );
    }
  }

  /// 지금까지 큐에 쌓인 저장 작업(JSON 저장 → SQLite 미러 쓰기 → `replayInto`)이
  /// 모두 끝날 때까지 기다린다 (S5.5.3 — [WeekLessonsCache]가 조회 전 쓰기와의
  /// 경쟁을 피하기 위해 호출한다).
  ///
  /// 공개 API는 계속 동기로 유지하면서(호출부를 async로 바꾸지 않기 위해)
  /// 필요한 곳에서만 명시적으로 "다 쓸 때까지 기다려" 달라고 요청하는
  /// 용도다 — `_storageQueue` 자체를 외부에 노출하지 않는다.
  Future<void> flushPendingWrites() => _storageQueue;

  /// 예약된 저장을 마친 뒤 특정 시간표의 교체 목록 파일을 삭제합니다.
  Future<void> clearStoredDataForTimetable(String timetableId) {
    return _enqueueStorageOperation(
      () => _storageService.clearExchangeList(timetableId: timetableId),
      '교체 리스트 삭제 실패',
    );
  }

  /// 교체 건에 인쇄 프로파일(계획서) 지정
  ///
  /// 메모리 항목을 갱신하고 로컬 저장소에 즉시 반영합니다.
  /// [profileId]가 null이면 미지정(기본 계획서 사용)으로 해제합니다.
  void assignProfile(String itemId, String? profileId) {
    final index = _exchangeList.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      AppLogger.warning('프로파일 지정 대상 교체 건을 찾을 수 없음: $itemId');
      return;
    }

    _exchangeList[index] = _exchangeList[index].copyWithProfileId(profileId);
    _exchangeListVersion++;
    _notifyVersionChanged();
    _saveToLocalStorage(_exchangeList[index]);
    AppLogger.info('교체 건 프로파일 지정: $itemId → $profileId');
  }

  /// 교체 건의 결강일·교체일 보정 (§10.10 — savedDates 대체)
  ///
  /// 결보강 계획서 화면에서 사용자가 날짜를 고쳤을 때 호출한다. 반환값은
  /// 갱신된 항목(찾지 못하면 null) — 호출부가 "다른 주로 이동했는지" 등을
  /// 갱신 전에 직접 판단해야 하므로, 이 메서드 자체는 그 판단을 하지 않고
  /// 그대로 반영만 한다.
  ExchangeHistoryItem? updateDates(
    String itemId, {
    DateTime? absenceDate,
    DateTime? substitutionDate,
  }) {
    final index = _exchangeList.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      AppLogger.warning('날짜 보정 대상 교체 건을 찾을 수 없음: $itemId');
      return null;
    }

    final updated = _exchangeList[index].copyWithDates(
      absenceDate: absenceDate,
      substitutionDate: substitutionDate,
    );
    _exchangeList[index] = updated;
    _exchangeListVersion++;
    _notifyVersionChanged();
    _saveToLocalStorage(updated);
    AppLogger.info(
      '교체 건 날짜 보정: $itemId → 결강 ${updated.absenceDate}, 교체 ${updated.substitutionDate}',
    );
    return updated;
  }

  /// 순환·2중 교체의 노드(슬롯) 하나에 확정 날짜를 지정한다 (S5.6).
  ///
  /// [updateDates]는 건드리지 않는다 — 1:1·보강은 노드가 2개뿐이라
  /// [updateDates]의 결강일·교체일 쌍만으로 이미 완전히 표현되므로, 이
  /// 메서드는 그 유일한 경로를 대체하지 않는다.
  ///
  /// 가드 2개(둘 다 걸리면 조용히 null만 반환하고 상태를 바꾸지 않는다):
  /// 1. 대상 항목이 순환·2중이 아니면([ExchangeHistoryItem.supportsNodeDates]
  ///    false) — 1:1·보강에 노드 날짜를 저장하면 아무도 읽지 않는 죽은
  ///    데이터가 조용히 쌓인다.
  /// 2. [date]의 실제 요일이 [dayName]과 다르면 — 슬롯 요일과 저장된 날짜의
  ///    요일이 어긋나면 OFF 모드 꼬리표가 엉뚱한 칸에 붙고 [ExchangeCellDates
  ///    .forWeek]의 주별 스코프가 깨진다([EventDateResolution]이 한 번 더
  ///    방어하지만, 애초에 잘못된 값을 저장하지 않는 편이 낫다).
  ///
  /// 반환값: 갱신된 항목(가드에 걸리거나 찾지 못하면 null).
  ExchangeHistoryItem? updateNodeDate(
    String itemId, {
    required String dayName,
    required int period,
    required DateTime date,
  }) {
    final index = _exchangeList.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      AppLogger.warning('노드 날짜 지정 대상 교체 건을 찾을 수 없음: $itemId');
      return null;
    }

    final item = _exchangeList[index];
    if (!item.supportsNodeDates) {
      AppLogger.warning('노드 날짜는 순환·2중 교체에만 지정할 수 있음: $itemId (${item.type.name})');
      return null;
    }
    if (date.weekday != DayUtils.getDayNumber(dayName)) {
      AppLogger.warning(
        '노드 날짜의 요일이 슬롯과 일치하지 않음: $itemId, 슬롯=$dayName, 지정한 날짜=$date',
      );
      return null;
    }

    final updated = item.copyWithNodeDate(dayName, period, date);
    _exchangeList[index] = updated;
    _exchangeListVersion++;
    _notifyVersionChanged();
    _saveToLocalStorage(updated);
    AppLogger.info('교체 건 노드 날짜 지정: $itemId, $dayName|$period → $date');
    return updated;
  }

  /// 메모리 상태만 초기화 (파일은 건드리지 않음)
  ///
  /// 활성 시간표가 모두 삭제된 경우 레거시 파일의 고스트 데이터가
  /// 로드되지 않도록 스코프 해제와 함께 사용합니다.
  void resetInMemoryState() {
    _exchangeList.clear();
    _undoStack.clear();
    _redoStack.clear();
    _exchangeListVersion++;
    _notifyVersionChanged();
    AppLogger.info('교체 리스트 메모리 상태 초기화 (파일 미변경)');
  }

  /// 로컬 저장소에서 교체 리스트 로드
  ///
  /// 프로그램 시작 시 호출되어 저장된 교체 리스트를 메모리로 로드합니다.
  /// 시간표 스코프 전환 시에도 호출되므로, 되돌리기/다시실행 스택도 함께
  /// 초기화합니다 (다른 시간표의 셀을 되돌리는 사고 방지).
  Future<void> loadFromLocalStorage() async {
    try {
      final requestedTimetableId = timetableId;

      // A scope can be switched immediately after a synchronous history
      // mutation. Read only after all earlier writes for that scope finish.
      await _storageQueue;

      // S5.4b: 이 시간표가 이미 SQLite로 이관됐으면(=이전에 한 번이라도
      // mirrorSink가 성공했으면) 거기서 읽는다 — "여기서부터 신규가 진실
      // 원본"이다. 아직 이관 전이면(SQLite에 아무것도 없으면) 아래 JSON
      // 경로로 폴백하고, 그 결과를 최초 1회 SQLite로 이관한다.
      if (requestedTimetableId != null) {
        final sqliteLoad = loadSink;
        if (sqliteLoad != null) {
          try {
            final sqliteItems = await sqliteLoad(requestedTimetableId);
            if (sqliteItems.isNotEmpty) {
              if (timetableId != requestedTimetableId) return;

              _undoStack.clear();
              _redoStack.clear();
              _exchangeList.clear();
              _exchangeList.addAll(sqliteItems);
              _legacyDataBackedUp = false;

              _exchangeListVersion++;
              _notifyVersionChanged();

              AppLogger.info(
                '교체 리스트 로드 완료(SQLite): ${_exchangeList.length}개 항목',
              );
              return;
            }
          } catch (e) {
            AppLogger.error('SQLite 교체 이력 로드 실패, JSON으로 폴백: $e', e);
          }
        }
      }

      // 스코프 전환 대비: 이전 시간표의 undo/redo 스택 초기화
      final loadResult = await _storageService.loadExchangeList(
        timetableId: requestedTimetableId,
      );

      // Ignore a slow load when another timetable became active meanwhile.
      if (timetableId != requestedTimetableId) {
        return;
      }

      // 메모리 교체 리스트를 로드된 데이터로 교체
      _undoStack.clear();
      _redoStack.clear();
      _exchangeList.clear();
      _exchangeList.addAll(loadResult.items);
      _legacyDataBackedUp = loadResult.legacyBackupPerformed;

      // 버전 증가 (UI 업데이트 트리거)
      _exchangeListVersion++;
      _notifyVersionChanged();

      AppLogger.info('교체 리스트 로드 완료: ${_exchangeList.length}개 항목');

      // S5.1 보완: mirrorSink는 "쓰기" 때만 호출되므로, mirrorSink가 붙기
      // 전에 이미 JSON에 있던 교체 이력은 새 저장이 한 번도 일어나지 않으면
      // SQLite 저널에 영원히 반영되지 않는다(S5.2 확인 패널에서 "불일치"로
      // 계속 보이는 원인). 로드 직후 한 번 미러를 밀어 넣어 이 간극을 바로
      // 닫는다 — JSON을 다시 쓰지 않으므로 진실 원본은 그대로 JSON이다.
      final sink = mirrorSink;
      final scopedTimetableId = timetableId;
      if (sink != null && scopedTimetableId != null) {
        _enqueueStorageOperation(
          () => sink(
            List<ExchangeHistoryItem>.from(_exchangeList),
            scopedTimetableId,
          ),
          '교체 이벤트 SQLite 미러 초기 동기화 실패',
        );
      }
    } catch (e) {
      AppLogger.error('교체 리스트 로드 실패: $e', e);
    }
  }

  // ========== 디버그 콘솔 출력 메서드들 ==========

  /// 교체 리스트를 콘솔에 출력
  void printExchangeList() {
    _printList('[교체 리스트]', _exchangeList);
  }

  /// 되돌리기 히스토리를 콘솔에 출력
  void printUndoHistory() {
    _printList('[되돌리기 히스토리]', _undoStack);
  }

  /// 다시 실행 히스토리를 콘솔에 출력
  void printRedoHistory() {
    _printList('[다시 실행 히스토리]', _redoStack);
  }

  /// 공통 리스트 출력 메서드
  void _printList(String title, List<ExchangeHistoryItem> list) {
    AppLogger.exchangeInfo('$title 총 ${list.length}개');
    if (list.isEmpty) {
      AppLogger.exchangeInfo('  비어있습니다.');
    } else {
      for (int i = 0; i < list.length; i++) {
        final item = list[i];
        AppLogger.exchangeInfo(
          '  ${i + 1} Type: ${item.type.displayName} - ${_getNodeInfo(item.originalPath)}',
        );
      }
    }
  }

  /// 전체 히스토리 통계를 콘솔에 출력
  void printHistoryStats() {
    final stats = getExchangeListStats();
    AppLogger.exchangeInfo('\n=== 교체 히스토리 통계 ===');
    AppLogger.exchangeInfo('전체 교체: ${stats['total']}개');
    AppLogger.exchangeInfo('활성 교체: ${stats['active']}개');
    AppLogger.exchangeInfo('되돌린 교체: ${stats['reverted']}개');
    AppLogger.exchangeInfo('되돌리기 가능: ${_undoStack.length}개');
    AppLogger.exchangeInfo('다시 실행 가능: ${_redoStack.length}개');

    final typeStats = stats['typeStats'] as Map<ExchangePathType, int>;
    AppLogger.exchangeInfo('\n교체 타입별 통계:');
    typeStats.forEach((type, count) {
      AppLogger.exchangeInfo('  ${type.displayName}: $count개');
    });

    if (stats['lastExchange'] != null) {
      AppLogger.exchangeInfo('\n마지막 교체: ${stats['lastExchange']}');
    }
    AppLogger.exchangeInfo('========================\n');
  }

  /// ExchangePath에서 노드 정보를 요약해서 반환
  String _getNodeInfo(ExchangePath path) {
    try {
      if (path is OneToOneExchangePath) {
        return _formatNodes([path.sourceNode, path.targetNode]);
      } else if (path is CircularExchangePath) {
        return _formatNodes(path.nodes);
      } else if (path is DualExchangePath) {
        // 2중교체: 4개 노드 모두 출력 (node1, node2, nodeA, nodeB)
        return _formatNodes([path.node1, path.node2, path.nodeA, path.nodeB]);
      } else if (path is SupplementExchangePath) {
        return _formatNodes([path.sourceNode, path.targetNode]);
      }
    } catch (e) {
      developer.log('노드 정보 추출 실패: $e');
    }
    return path.displayTitle;
  }

  /// 노드 리스트를 포맷팅
  String _formatNodes(List<dynamic> nodes) {
    return nodes
        .asMap()
        .entries
        .map((entry) {
          final node = entry.value;
          return '[${entry.key}]${node.day}|${node.period}|${node.className}|${node.teacherName}|${node.subjectName}';
        })
        .join(', ');
  }

  /// 특정 셀이 교체된 셀인지 확인 (활성 교체만)
  bool isCellExchanged(String teacherName, String day, int period) {
    for (final item in _exchangeList) {
      if (item.isReverted) continue;
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return true;
      }
    }
    return false;
  }

  /// 교체된 셀에 해당하는 교체 경로 찾기 (활성 교체만)
  ExchangePath? findExchangePathByCell(
    String teacherName,
    String day,
    int period,
  ) {
    for (final item in _exchangeList) {
      if (item.isReverted) continue;
      if (_isCellInExchangePath(item.originalPath, teacherName, day, period)) {
        return item.originalPath;
      }
    }
    return null;
  }

  /// ExchangePath에서 특정 셀이 포함되어 있는지 확인
  bool _isCellInExchangePath(
    ExchangePath path,
    String teacherName,
    String day,
    int period,
  ) {
    try {
      final nodes = _getNodesFromPath(path);
      return nodes.any(
        (node) =>
            node.teacherName == teacherName &&
            node.day == day &&
            node.period == period,
      );
    } catch (e) {
      developer.log('셀 확인 중 오류 발생: $e');
      return false;
    }
  }

  /// ExchangePath에서 노드 리스트 추출
  List<dynamic> _getNodesFromPath(ExchangePath path) {
    if (path is OneToOneExchangePath) {
      return [path.sourceNode, path.targetNode];
    } else if (path is CircularExchangePath) {
      return path.nodes;
    } else if (path is DualExchangePath) {
      return [path.nodeA, path.nodeB, path.node1, path.node2];
    } else if (path is SupplementExchangePath) {
      return [path.sourceNode, path.targetNode];
    }
    return [];
  }
}
