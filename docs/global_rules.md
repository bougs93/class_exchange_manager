### 1 구현 작업 원칙

- 비즈니스 로직 구현 작업은 반드시 테스트를 먼저 작성하고 구현하세요.
- SOLID 원칙을 사용해서 구현하세요
- Clean Architecture를 사용해서 구현하세요
- **Riverpod 상태 관리를 필수로 사용하세요** (자세한 내용은 아래 섹션 6 참고)
- Pulumi나 CloudFormation에 설정하는 Description은 영문으로 작성하세요.

### 2 코드 품질 원칙

- 단순성: 언제나 복잡한 솔루션보다 가장 단순한 솔루션을 우선시하세요.
- 중복 방지: 코드 중복을 피하고, 가능한 기존 기능을 재사용하세요 (DRY 원칙).
- 가드레일: 테스트 외에는 개발이나 프로덕션 환경에서 모의 데이터를 사용하지 마세요.
- 효율성: 명확성을 희생하지 않으면서 토큰 사용을 최소화하도록 출력을 최적화하세요.

### 3 리팩토링

- 리팩토링이 필요한 경우 계획을 설명하고 허락을 받은 다음 진행하세요.
- 코드 구조를 개선하는 것이 목표이며, 기능 변경은 아닙니다.
- 리팩토링 후에는 모든 테스트가 통과하는지 확인하세요.

### 4 디버깅

- 디버깅 시에는 원인 및 해결책을 설명하고 허락을 받은 다음 진행하세요.
- 에러 해결이 중요한 것이 아니라 제대로 동작하는 것이 중요합니다.
- 원인이 불분명할 경우 분석을 위해 상세 로그를 추가하세요.

### 5 언어

- AWS 리소스에 대한 설명은 영문으로 작성하세요.
- 기술적인 용어나 라이브러리 이름 등은 원문을 유지합니다.
- 간단한 다이어그램은 mermaid를 사용하고, 복잡한 아키텍처 다이어그램은 별도의 svg 파일을 생성하고 그걸 문서에 포함시킬것.

### 6 Riverpod 상태 관리 규칙 (필수)

#### 6.1 기본 원칙
- **모든 애플리케이션 상태는 Riverpod Provider로 관리**
- `setState()` 사용 금지 (로컬 UI 상태 제외)
- 새로운 화면이나 위젯 작성 시 반드시 Riverpod 패턴 사용

#### 6.2 UI 컴포넌트 작성 규칙
- **상태가 있는 화면**: `ConsumerWidget` 또는 `ConsumerStatefulWidget` 사용
- **상태가 없는 화면**: `StatelessWidget` 사용
- **일반 StatefulWidget 사용 금지** (아래 예외 제외)

#### 6.3 허용되는 StatefulWidget 사용 (예외)
다음 경우에만 StatefulWidget 사용 허용:
- 애니메이션 컨트롤러 관리 (`AnimationController`)
- 스크롤 컨트롤러 관리 (`ScrollController`)
- 포커스 노드 관리 (`FocusNode`)
- 텍스트 컨트롤러 관리 (`TextEditingController`)
- 기타 순수 UI 로컬 상태 (애플리케이션 상태가 아님)

#### 6.4 Provider 타입 선택
- **StateNotifierProvider**: 복잡한 상태 관리 (여러 필드, 복잡한 로직)
  ```dart
  // 예: 교체 화면 상태 (30+ 필드)
  final exchangeScreenProvider = StateNotifierProvider<ExchangeScreenNotifier, ExchangeScreenState>((ref) {
    return ExchangeScreenNotifier();
  });
  ```
- **StateProvider**: 간단한 단일 값 상태
  ```dart
  // 예: 네비게이션 인덱스
  final navigationProvider = StateProvider<int>((ref) => 0);
  ```
- **Provider**: 서비스 인스턴스 제공 (불변)
  ```dart
  // 예: 서비스 인스턴스
  final excelServiceProvider = Provider<ExcelService>((ref) => ExcelService());
  ```

#### 6.5 상태 접근 패턴
- **ref.watch()**: 반응형 UI 업데이트 (build 메서드에서 사용)
  ```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exchangeScreenProvider);
    // state 변경 시 자동으로 rebuild
  }
  ```
- **ref.read()**: 일회성 상태 접근 (이벤트 핸들러에서 사용)
  ```dart
  void onTap() {
    final notifier = ref.read(exchangeScreenProvider.notifier);
    notifier.updateState();
  }
  ```
- **ref.listen()**: 상태 변경 리스너 (사이드 이펙트 처리)
  ```dart
  ref.listen(exchangeScreenProvider, (previous, next) {
    if (next.error != null) {
      showDialog(...);
    }
  });
  ```

#### 6.6 상태 업데이트 패턴
- **copyWith 패턴 사용**: 불변 상태 업데이트
  ```dart
  class ExchangeScreenState {
    final File? selectedFile;
    final bool isLoading;

    ExchangeScreenState copyWith({
      File? Function()? selectedFile,
      bool? isLoading,
    }) {
      return ExchangeScreenState(
        selectedFile: selectedFile != null ? selectedFile() : this.selectedFile,
        isLoading: isLoading ?? this.isLoading,
      );
    }
  }

  // Notifier에서 사용
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
  ```

#### 6.7 금지 사항
- ❌ `StatefulWidget` + `setState()` (로컬 UI 상태 제외)
- ❌ Provider 없이 전역 변수로 상태 관리
- ❌ `InheritedWidget`을 직접 사용한 상태 관리
- ❌ 다른 상태 관리 라이브러리 사용 (Provider, GetX, Bloc 등)
