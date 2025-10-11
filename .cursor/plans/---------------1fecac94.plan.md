<!-- 1fecac94-9cd6-4f0d-9613-a5cc435e96e9 3cea28c9-a3d2-493d-a74f-929a1ff2588e -->
# 교체 뷰 백업 시스템 개선

## 개요

현재 전체 timeSlots를 백업하는 방식에서, 변경된 셀의 원본 정보만 저장하는 경량화된 방식으로 변경합니다.

## 구현 단계

### 1. 백업용 데이터 구조 추가

**파일**: `lib/ui/widgets/timetable_grid_section.dart`

- `_exchangeList_work` 리스트 생성 (클래스 멤버 변수로 추가)
- 각 아이템은 복원에 필요한 최소 정보만 포함:
- teacher (교사명)
- dayOfWeek (요일)
- period (교시)
- subject (과목)
- className (학급명)

### 2. _enableExchangeView 메서드 수정

**파일**: `lib/ui/widgets/timetable_grid_section.dart`

**핵심 수정**:

- TimeSlot 객체를 찾아서 백업하는 방식 제거
- ExchangeNode에서 직접 [teacher, dayOfWeek, period, subject, className] 데이터만 추출하여 백업
- TimeSlots에서 현재 subject와 className만 조회하여 저장

### 3. _disableExchangeView 메서드 수정

**파일**: `lib/ui/widgets/timetable_grid_section.dart` (927-951줄)

**제거할 기능**:

- `timeSlotsBackupProvider` 관련 복원 코드 삭제 (931-947줄)

**추가할 기능**:

- `_exchangeList_work` 리스트를 순회하며:
- 각 백업 정보의 teacher, dayOfWeek, period로 해당 TimeSlot 찾기
- 해당 TimeSlot의 subject, className을 백업된 값으로 복원
- DataSource 갱신 (`widget.dataSource!.notifyDataSourceListeners()`)
- `_exchangeList_work.clear()` 호출하여 리스트 비우기

### 4. 검증 및 테스트

- 교체 뷰 활성화 시 변경된 셀 정보가 올바르게 저장되는지 확인
- 교체 뷰 비활성화 시 원본 상태로 정확히 복원되는지 확인
- 로그를 통해 백업/복원 과정 추적

## 주요 변경 사항

1. **메모리 효율성**: 전체 timeSlots 백업 → 변경된 셀만 백업
2. **데이터 구조**: `TimeSlotsBackupProvider` 사용 중단 → `_exchangeList_work` 리스트 사용
3. **복원 방식**: 전체 교체 → 변경된 셀만 선택적 복원

## 영향을 받는 파일

- `lib/ui/widgets/timetable_grid_section.dart`: 주요 로직 수정

### To-dos

- [ ] _exchangeList_work 리스트 변수를 TimetableGridSection 클래스에 추가
- [ ] _enableExchangeView 메서드 수정: 백업 생성 제거 및 변경된 셀 정보 저장 로직 추가
- [ ] _disableExchangeView 메서드 수정: 백업 복원 제거 및 _exchangeList_work 기반 복원 로직 추가
- [ ] 교체 뷰 활성화/비활성화 테스트 및 로그 확인