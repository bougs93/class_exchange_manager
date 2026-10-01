# 교체 화면 웹 성능 개선

## 적용 내용

- Firebase Hosting에 COOP `same-origin`, COEP `credentialless`를 설정했다.
  지원 브라우저에서 WASM 렌더러가 멀티스레드를 사용할 수 있게 한다.
- 교체 화면 상위 위젯은 시간표·컬럼·모드·선택 경로 등 화면 구성에 필요한 값만 구독한다.
  진행률·검색·필터·탐색 결과는 사이드바 Consumer에서 구독한다.
- DataGrid 위젯을 재사용해 경로 선택 시 컬럼 스케일링과 그리드 전체 재생성을 피한다.
- 순환·2중교체 탐색을 `lib/services/search`의 순수 Dart 엔진으로 분리했다.
  네이티브 서비스와 웹 Worker가 같은 알고리즘을 사용한다.
- 탐색마다 교사/시간·학급 인덱스를 생성하고, 순환 탐색의 인접 노드와 검증 인덱스를 재사용한다.
  시간표 변경 후 이전 탐색의 인덱스를 재사용하지 않는다.
- 웹에서는 탐색을 Worker로 실행한다. 진행 중인 탐색을 취소하면 Worker를 종료하고,
  완료 후 대기 중인 Worker는 재사용한다. 셀·모드·주·시간표가 바뀌면 오래된 결과를 버린다.
- 그리드는 연속 알림을 모으고, 셀의 값·선택·경로·교체 표시·테마를 비교해 바뀐 셀에만
  `notifyDataSourceListeners(rowColumnIndex: ...)`를 보낸다. 교사·컬럼 구조가 같으면 기존 행을 유지한다.

## 웹 빌드

Flutter 앱과 탐색 Worker가 모두 배포되어야 한다.

```powershell
dart run tool/build_web.dart --no-wasm-dry-run
```

기존 `--dart-define=...` 옵션은 뒤에 그대로 전달한다.
CI의 `deploy-web.yml`에도 Flutter 빌드 다음에 동일한 Worker 컴파일 단계가 있다.
스크립트는 Flutter 빌드 성공 후 `build/web/exchange_search_worker.js`를 생성하며,
Worker 컴파일 실패 시 실패 코드로 종료한다. Firebase는 이 파일에 `no-cache`를 적용한다.

`flutter run`으로 웹을 개발할 때에는 먼저 Worker를 웹 소스 폴더에 생성한다.

```powershell
dart compile js -O2 '-Ddart.vm.product=true' tool/exchange_search_worker.dart -o web/exchange_search_worker.js
flutter run -d chrome
```

탐색 엔진을 수정하면 Worker도 다시 컴파일한다. Worker는 순수 Dart를 JavaScript로 컴파일하므로
앱이 WASM 또는 JavaScript로 실행되는 경우 모두 사용할 수 있다.
현재 CI는 `excel 4.x / archive 3.x`의 WASM XLSX 호환성 문제로 JavaScript 빌드를 사용한다.
따라서 COOP/COEP 헤더를 추가하는 것만으로 WASM 멀티스레드가 활성화되지는 않는다.
의존성 호환성을 해결한 뒤 빌드 명령에 `--wasm`을 전달하고 실제 동작을 확인해야 한다.
Worker 파일이 없거나 실행에 실패하면 오류를 표시한다. 무거운 계산을 UI 스레드에서 다시 실행하지 않는다.

## 검증 기록 (2026-10-02)

- 관련 기존 테스트 13개와 신규 탐색·실제 SfDataGrid 갱신 테스트 4개 통과.
- 수정 범위 정적 분석 오류·경고 없음.
- 변경 전 탐색 코드와 합성 시간표 4개(각 교사 50명, 1,750칸)를 비교했다.
  순환·2중교체 64건에서 반환된 4,720개 경로의 노드 구성이 일치했다.
- 같은 로컬 Dart 실행에서 합산 탐색 시간: 변경 전 12,416ms, 변경 후 2,832ms.
  단일 로컬 실행이며 브라우저 렌더링·직렬화·네트워크를 포함한 전체 성능 수치가 아니다.
- 실제 Worker JavaScript 컴파일 및 Worker 호출부의 JavaScript/WASM 컴파일 성공.
- Node Worker Threads로 브라우저 Worker API를 대체한 호출부 검증:
  응답 수신, 진행 중 취소, 새 요청으로 교체, 취소 후 재실행 통과.
- 전체 Flutter 웹 빌드는 SDK의 `bin/cache/lockfile` 쓰기 권한 제한으로 완료하지 못했다.
  브라우저 실행도 CDP 연결 종료로 실패했다. 실제 배포 화면의 로그인·스크롤·WASM 멀티스레드
  활성화와 변경 전후 프레임 시간은 추가 확인이 필요하다. 운영 배포는 수행하지 않았다.

배포 후에는 응답 헤더와 `window.crossOriginIsolated === true`를 확인하고,
실제 WASM 실행 및 skwasm 렌더러 사용 여부를 함께 확인한다. 날짜 변경·교체·되돌리기·로그인과
외부 PDF 리소스 로딩도 점검한다.
