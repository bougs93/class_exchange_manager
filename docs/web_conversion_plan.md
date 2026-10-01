# 웹(Web) 전환 계획서

## 1. 배경 및 목표

현재 앱은 PC(Windows)·모바일 전용으로 설계되어 있으며, 개인 시간표/교체 이력을
`sqflite_common_ffi` 기반 로컬 SQLite에 저장한다. 교사들이 설치 없이 브라우저로
접근할 수 있도록 **웹 버전**을 추가한다.

> **범위 확정 (Opus 검토 반영, 2026-10-01)**: 이번 전환은 웹 버전에
> 신규 기능(로그인, 공용 시간표 동기화)을 추가하는 것이 목표이며, PC/모바일
> 앱의 **동작**은 바뀌지 않는다. 다만 `dart:io`를 쓰는 공용 파일
> (`timetable_database.dart`, `storage_service.dart` 등)은 웹에서 아예
> 컴파일이 안 되기 때문에, 조건부 import로 **파일을 플랫폼별로 쪼개는
> 작업 자체는 필요하다** — "코드를 안 건드린다"가 아니라 "동작·로직은
> 그대로 두고 분리만 한다"가 정확한 표현이다 (6장 참고).

### 확정된 요구사항

1. **관리자 비밀번호 1개** — 공용 시간표를 등록/수정할 수 있는 권한 (웹 전용)
   - 비밀번호 분실 시, **마스터 계정(ID + 비밀번호)**으로도 관리자 모드 진입
     가능 — 단일 비밀번호가 아니라 ID·비밀번호 조합으로 강화 (4.2절)
2. **접속자 비밀번호 1개** — 앱 조회(사용) 권한 (웹 전용, 단순 비밀번호 유지)
   - 관리자 모드 로그인 후, 관리자가 접속자 비밀번호를 직접 설정/변경 가능
   - 비밀번호와 함께 보여줄 안내 메시지도 관리자가 설정 가능
3. **데이터 분리 운영**
   - 전체(공용) 시간표: 웹에서는 서버(Firebase)로 공용 관리, 모든 웹 사용자가 동일하게 조회
   - 사용 중 발생하는 교체 등 개인 작업 데이터: 로컬(브라우저)에서만 관리
   - 로컬 데이터는 기기를 바꾸거나 다른 PC/브라우저에서 접속 시 **삭제되어도 무방** (동기화 불필요)
4. **PC/모바일은 기존 방식 그대로** — 서버(Firebase)에 전혀 접속하지 않고,
   지금처럼 완전히 오프라인으로 동작 (동작 기준, 1장 상단 범위 확정 참고)

### 비목표 (이번 전환 범위에서 제외)

- PC/모바일에 로그인·공용 시간표 동기화 추가 (요구사항 4번에 따라 제외)
- 사용자별 개별 계정/권한 체계 (비밀번호는 "관리자용 1개 + 접속자용 1개"로 고정)
- 로컬 데이터의 기기 간 동기화·백업 (삭제되어도 무방하다는 전제)
- 공용 시간표의 실시간 동시 편집(관리자는 1명을 전제로 함), 버전 관리/롤백
- 기존 로컬 데이터와의 하위 호환성 유지 (호환성 불필요로 확정)
- 접근 제어를 암호학적으로 강하게 거는 것 — 민감 정보가 없다는 전제하에
  **사용 편의성**을 우선한다. 다만 "비밀번호 평문이 아무나 읽을 수 있는 곳에
  공개되는 것"은 사회적 장벽으로서도 의미가 없으므로 최소한의 보호(해시 저장,
  읽기 범위 분리)는 적용한다 (4장 참고)

## 2. 전체 아키텍처

> **호스팅: Cloudflare Pages 사용 확정.** Cloudflare Pages는 정적 파일
> 호스팅만 제공하므로(`flutter build web` 산출물 배포), 인증과 공용 시간표
> 저장소는 별도 백엔드 서비스가 필요하다 — 이 역할은 Firebase
> (Firestore + Storage)가 담당한다. 단, Cloudflare Pages 기본 빌드
> 이미지에는 Flutter SDK가 없으므로 GitHub Actions 등에서 빌드 후
> 배포하는 방식을 쓴다 (8장 5단계).

```
┌───────────────────────────────┐        ┌──────────────────────────────┐
│   PC / 모바일 (기존, 동작 동일)   │        │   웹 (Cloudflare Pages 배포)    │
│                                │        │                                │
│  로컬 Excel 파일 가져오기         │        │  Firebase 접속 비밀번호 화면     │
│  로컬 SQLite + 로컬 JSON 저장소  │        │       ↓                        │
│  (sqflite / sqflite_common_ffi,│        │  공용 시간표 조회·캐싱 (JSON,    │
│   storage_service_io.dart)     │        │  Firestore/Storage) + 관리자 모드│
│  완전 오프라인                  │        │  업로드                         │
│                                │        │       +                        │
│                                │        │  개인 작업 데이터는 로컬           │
│                                │        │  (sqflite_common_ffi_web +      │
│                                │        │   storage_service_web.dart, 신규)│
└───────────────────────────────┘        └──────────────────────────────┘
                                                        │
                                                        ▼
                                          Firebase (Firestore + Storage,
                                          Blaze 요금제 — 9장 참고)
                                          - config/public: 안내 메시지 (공개 읽기)
                                          - config/auth: 비밀번호 해시 (로그인 필요)
                                          - config/sharedTimetable: 버전 마커
                                          - 공용 시간표 JSON (Storage, 4장)
```

### 설계 원칙

- **로컬 DB·저장소의 스키마·쿼리·Repository 로직은 바꾸지 않는다.** 웹에서도
  개인 작업 데이터는 기존 코드 그대로 쓰되, `dart:io`를 참조하는 파일만
  조건부 import로 플랫폼별 구현으로 쪼갠다 (6장).
- **공용 시간표는 "파일 통째 전송"이 아니라 "데이터(JSON) 전송 후 로컬
  DB에 적용"하는 방식으로 동기화한다.** 당초 검토했던 "SQLite `.db` 파일을
  그대로 Storage에 올리고 웹에서 열기" 방식은 `sqflite_common_ffi_web`에
  외부 바이트를 파일처럼 주입하는 공개 API가 없어 기술적으로 성립하지
  않는 것으로 확인되어 폐기한다 (4장).
- **보안보다 편의성, 단 최소한의 보호는 적용.** 비밀번호는 "아무나 못
  들어오게 막는 사회적 장벽" 수준으로 취급하되, 평문이 비로그인 상태에서도
  그대로 노출되는 구조는 쓰지 않는다 (4.1·4.3절).

## 3. 비즈니스 임팩트가 큰 변경: 공용 시간표 동기화 방식 재설계

### 3.1 왜 "SQLite 파일 통째 전송"을 포기했는가

- `sqflite_common_ffi_web`은 `sqlite3.wasm` + 전용 워커 자산을 설치해 동작하며,
  "다운로드한 임의의 `.db` 바이트를 파일처럼 열어 기존 쿼리로 조회"하는
  경로를 공식적으로 지원하지 않는다.
- 설령 우회 방법을 찾더라도, 서버의 공용 `.db` 파일 스키마 버전과 접속자
  앱의 `TimetableDatabase.schemaVersion`이 어긋나면 `openDatabase`가
  실패하거나 의도치 않은 `onUpgrade`가 실행되는 문제가 생긴다.

### 3.2 대안: JSON 데이터로 전송하고 로컬 DB에 반영

1. **관리자가 공용 시간표를 갱신할 때**
   - 로컬에 이미 열려 있는 SQLite(관리자 자신의 로컬 DB)에서 해당
     시간표의 `Lesson` 레코드 목록을 조회
   - 기존에 쓰이는 `Lesson.toMap()`을 그대로 사용해 `List<Map>` →
     `jsonEncode`로 직렬화
   - 이 JSON 문자열(바이트)을 Firebase Storage에 업로드 (파일 자체는
     `.db`가 아니라 `.json`)
2. **웹 사용자가 조회할 때**
   - Storage에서 JSON 바이트 다운로드 → `jsonDecode`
   - 각 레코드를 기존 `Lesson.fromMap()`으로 역직렬화
   - **이미 열려 있는 로컬(웹) SQLite 연결**에, 공용 시간표 전용 테이블
     (또는 기존 테이블에 `source='shared'` 같은 구분 컬럼)로 트랜잭션 내에서
     "기존 공용 데이터 삭제 → 새 데이터 삽입"
3. **효과**
   - 외부 `.db` 파일을 여는 미검증 경로를 쓰지 않고, 이미 열려 있는 로컬
     DB에 대한 **표준 `insert`/`batch` 호출**만 사용 → 웹에서 실제로
     동작이 보장되는 API만 사용
   - 스키마 버전은 "그 순간 실행 중인 앱 코드의 스키마"를 따르므로
     서버-클라이언트 스키마 불일치 문제가 발생하지 않음
   - 기존 `Lesson` 모델의 직렬화 메서드를 재사용하므로 신규 코드가 많지 않음

### 3.3 캐싱 전략 (버전 비교 후 다운로드)

JSON으로 포맷만 바뀌었을 뿐, 캐싱 로직 자체는 이전과 동일한 원칙을 따른다.

- Firestore `config/sharedTimetable` 문서에 `version`(정수) 저장
- **권장 순서**: 관리자가 업로드할 때 **"버전 먼저 증가 → JSON 업로드"**
  순서로 진행 (반대로 하면 업로드 중간에 실패해도 버전만 올라가 있어
  클라이언트가 "최신인데 왜 안 바뀌었지" 하고 재확인하게 되는 쪽이,
  업로드 성공 후 버전 갱신 실패로 **영구히 구버전에 고착**되는 것보다 안전)
- 웹 클라이언트 접속 시:
  1. 로컬에 캐시된 공용 시간표 JSON과 그 버전이 **있는지 확인**
  2. 있다면 Firestore에서 `version`만 먼저 읽어 (가벼운 읽기) 로컬 캐시
     버전과 비교
  3. **다운로드 조건(둘 중 하나라도 해당하면 실행)**:
     - 로컬에 캐시가 **아예 없는 경우** (최초 접속, 캐시 삭제 후 재접속 등)
     - 로컬 캐시 버전과 Firestore `version`이 **다른 경우**
  4. 둘 다 아니면 로컬 데이터를 그대로 재사용, Storage 다운로드 생략
- PC/모바일에는 적용하지 않음 (Firebase 미접속)

## 4. 인증/접근 제어 (웹 전용)

### 4.1 비밀번호 저장 방식 — 설정 문서를 공개/비공개로 분리

이전 안은 Firestore `config/auth` 문서를 통째로 공개 읽기(`read: if true`)
처리해서, **접속자/관리자 비밀번호 평문이 로그인 없이도 그대로 노출**되는
문제가 있었다 (Opus 검토 지적). 민감 정보가 없다는 전제와는 별개로,
비밀번호 자체가 아무 보호 없이 공개되면 "사회적 장벽"으로서도 기능하지
않으므로 최소한의 분리를 적용한다.

```
config/public 문서  (읽기: 누구나 가능 — 로그인 화면에 필요)
{
  "loginMessage": "..."      // 접속 화면에 보여줄 안내 문구, 관리자가 설정
}

config/auth 문서  (읽기: 로그인 필요 — 4.4절 Firestore 규칙)
{
  "viewerPasswordHash": "...",  // salted SHA-256 해시, 관리자가 설정/변경
  "adminPasswordHash": "..."    // salted SHA-256 해시, 관리자가 설정/변경
}
```

- `crypto` 패키지(이미 의존성에 포함됨)로 간단한 salted hash를 적용한다.
  진짜 암호학적 보안이 목적이 아니라, "브라우저 개발자도구만 열어봐도
  비밀번호가 그대로 보이는" 최소 수준의 허점을 막기 위함이다.
- `viewerPasswordHash`는 관리자 로그인 후에만 관리자 메뉴에서 변경 가능.

### 4.2 관리자 비밀번호 분실 대비 — 마스터 계정(ID + 비밀번호)

단일 마스터 비밀번호 대신, **ID + 비밀번호 조합**으로 강화한다.

- `lib/config/master_credentials.dart`에 `masterId`, `masterPasswordHash`를
  상수로 고정 (앱 코드에 포함되므로 빌드 산출물에서 추출이 가능하다는
  한계는 동일하게 남지만, 두 값을 모두 알아야 하므로 추측 공격 난이도는 올라감)
- 관리자 로그인 화면은 평소에는 비밀번호 1개 입력란만 보여주고,
  "비밀번호를 잊으셨나요?" 같은 보조 링크를 눌렀을 때만 **ID + 비밀번호**
  입력란이 있는 마스터 로그인 폼이 나타나는 구조로 UI를 분리한다
- 마스터 계정으로 로그인에 성공하면 즉시 관리자 권한으로 진입하며,
  이 상태에서 `adminPasswordHash`를 새로 설정하도록 유도

### 4.3 접속 흐름

1. 웹 앱 최초 진입 → `config/public.loginMessage` 조회해 안내 문구와 함께
   비밀번호 입력창 표시 (이 단계는 비로그인 상태에서도 가능해야 함)
2. 입력값의 해시가 `config/auth.viewerPasswordHash`와 일치하면 통과 →
   공용 시간표 조회 가능 (내부적으로 Firebase 익명 인증을 먼저 수행해
   `config/auth` 읽기 조건을 만족시킴)
3. 관리자 모드: 입력값의 해시가 `adminPasswordHash`와 일치하거나, 마스터
   ID+비밀번호가 일치하면 관리자 권한 부여 → 공용 시간표 업로드/수정,
   `viewerPasswordHash`/`loginMessage` 변경 가능

### 4.4 Firestore/Storage 접근 규칙

```
// Firestore
match /config/public {
  allow read: if true;
  allow write: if request.auth != null;   // 관리자만 쓰도록 앱 로직에서 제한 (느슨한 보호, 9장 참고)
}
match /config/auth {
  allow read: if request.auth != null;    // 익명 로그인만 되어도 읽기 가능 — viewer 비밀번호 해시 노출 범위를 "로그인한 사람"으로 한정
  allow write: if request.auth != null;
}
match /config/sharedTimetable {
  allow read: if true;
  allow write: if request.auth != null;
}

// Storage (공용 시간표 JSON)
match /shared_timetable/{file} {
  allow read: if true;
  allow write: if request.auth != null;
}
```

- 앱은 화면 로드 시 Firebase **익명 인증(Anonymous Auth)**으로 자동
  로그인해 위 규칙의 `request.auth != null` 조건을 만족시킨다.
- **한계(의도적으로 수용하는 리스크)**: Firestore 구조를 아는 사람이
  작정하고 익명 인증 후 직접 요청을 보내면 비밀번호 해시값 자체는 읽을 수
  있고(복호화는 안 되지만 존재는 확인 가능), 쓰기도 가능하다. 요구사항상
  "보안보다 편의성"이 확정되어 있으므로 허용된 리스크로 간주하되, 평문
  노출만큼은 막는다.

### 4.5 세션 유지 (편의성 우선)

- 로그인 성공 여부(뷰어/관리자)를 브라우저 로컬 저장소(`shared_preferences`
  웹 구현)에 저장
- 재방문 시 저장된 상태를 확인해 **비밀번호 재입력 없이 자동 통과**
- 로그아웃 메뉴는 선택 사항 (요구사항상 필수 아님)
- **주의**: iOS Safari 등 일부 브라우저는 장기 미사용 시 로컬 저장소를
  자동 삭제할 수 있어, 세션이 끊기고 로컬 개인 데이터도 함께 사라질 수
  있음 (요구사항상 "삭제돼도 무방"으로 확정되어 있어 별도 대응은 하지
  않되, 접속 화면에 안내 문구로 고지하는 것을 권장)

## 5. PC/모바일 동작에 영향 없음을 보장하는 작업 방식

웹 지원을 위해 다음 파일들을 **조건부 import(stub) 구조**로 분리한다.
플랫폼별 구현 내용은 그대로 옮기기만 하고 로직은 바꾸지 않으므로 PC/모바일
동작은 동일하게 유지되지만, **파일 분리 작업 자체는 필요**하다.

| 대상 파일 | 현재 상태 | 분리 방식 |
|---|---|---|
| `lib/data/timetable_database.dart` | `Platform.*` 분기, `path_provider` 사용 | `_io.dart`(기존 로직 이동) / `_web.dart`(`sqflite_common_ffi_web` + 고정 DB 이름) + 조건부 export |
| `lib/services/storage_service.dart` | `File`/`Directory`/`Platform.resolvedExecutable` 기반 JSON 저장소, **38개 파일에서 참조** | `_io.dart`(기존 로직 이동) / `_web.dart`(`shared_preferences` 또는 IndexedDB 기반 key-value로 재구현) + 조건부 export. 호출부(38개 파일) 수정 불필요 |
| `lib/services/timetable_storage_service.dart` | 파일 기반 저장 | 위와 동일한 패턴 적용 |

**조건부 export 예시** (`storage_service.dart`):
```dart
export 'storage_service_stub.dart'
  if (dart.library.io) 'storage_service_io.dart'
  if (dart.library.html) 'storage_service_web.dart';
```

### 5.1 1단계 착수 전 리스크 점검 (필수)

본격적인 분리 작업 전에, **지금 상태에서 `flutter build web`을 한 번
실행**해 전체 컴파일 에러 목록을 확보한다. `dart:io`를 참조하는 파일이
18개, `Platform.*`을 참조하는 파일이 13개로 조사되었으나, 실제 빌드
에러 로그를 봐야 숨어 있는 전이 의존성(예: 다른 서비스가 또 이 파일들을
import하는 경우)까지 빠짐없이 파악할 수 있다. 이 작업을 8장 1단계의
첫 번째 할 일로 포함한다.

## 6. 로컬 데이터(개인 작업) 처리

- 대상: 교체 이력, 개인 시간표 조정 등 — `lib/data/timetable_database.dart`,
  `lib/repositories/timetable_repository.dart`, `lib/services/storage_service.dart`,
  `lib/services/timetable_storage_service.dart`가 관리하는 데이터 전부
- **로직 변경 없음**: 스키마, 쿼리, Repository API, JSON 저장 포맷 전부 유지
  (5장의 조건부 import 분리만 적용)
- **플랫폼별 엔진**:
  - 모바일: 기존 `sqflite` 그대로 (변경 없음)
  - PC: 기존 `sqflite_common_ffi` 그대로 (변경 없음)
  - 웹(신규): `sqflite_common_ffi_web` + `storage_service_web.dart` 추가
- **삭제 허용 전제 반영**: 기기 변경/캐시 삭제 시 로컬 데이터가 사라지는 것을
  정상 동작으로 간주 → 복구/백업 로직 구현하지 않음 (요구사항과 일치)

### `timetable_database.dart` 웹 분기 상세

| 함수 | 현재 | 웹 대응 |
|---|---|---|
| `_ensureFfiInitialized()` | `Platform.isWindows/isLinux/isMacOS`만 분기 | `kIsWeb` 분기 추가, `databaseFactoryFfiWeb` 지정. `dart run sqflite_common_ffi_web:setup`으로 `web/`에 `sqlite3.wasm`/워커 자산 설치 필요 |
| `_defaultDatabasePath()` | `getApplicationSupportDirectory()` 사용 | 웹에서는 경로 개념이 없으므로 고정 DB 이름 사용 |
| `deleteDefaultDatabaseFile()` | `File(path)`로 직접 접근 | 웹에서는 `File` 사용 불가 → `deleteDatabase(path)`만 사용하도록 분기 |

## 7. 그 외 영향 범위 점검이 필요한 기능 (웹 전용)

| 기능 | 현재 방식 | 웹 전환 시 |
|---|---|---|
| PDF 내보내기 (`pdf_export_service`, `batch_pdf_export_service`) | `dart:io File`로 로컬 저장 | `printing` 패키지는 **웹 지원됨** — `Printing.sharePdf()`로 브라우저 다운로드/인쇄 다이얼로그 대체 가능. 다만 서비스 내부에 `Platform.*` 분기가 있어 그 부분은 정리 필요 |
| 엑셀 내보내기 (`excel_export_service`) | 로컬 디스크 저장 | 브라우저 다운로드(Blob)로 전환 필요 |
| 엑셀 업로드 (`excel_service.dart`) | `kIsWeb` 분기 존재하나 일부는 bytes만 읽고 `null` 반환하는 죽은 코드 | 실제 동작 경로는 `exchange_operation_manager._selectExcelFileWeb()`뿐 — 죽은 분기 정리 + 해당 경로로 통합 |
| 클립보드 이미지 붙여넣기 (`pasteboard`) | 네이티브 클립보드 API, **웹 미지원** | 브라우저 Async Clipboard API로 대체 필요 (HTTPS 필수, Firefox/Safari는 이미지 쓰기 제약 있음) → 웹에서는 기능 축소 가능성을 사용자에게 고지 |
| 개인 데이터 저장 디렉터리 (`path_provider`) | `getApplicationSupportDirectory()` 등 | **웹 미지원** — 5장의 조건부 import로 흡수 |
| `sqlite3_flutter_libs: ^0.6.0+eol` | EOL(지원 종료) 버전 고정 | 웹용 패키지(`sqflite_common_ffi_web`) 추가 시 버전 충돌 가능성 있어 사전 확인 필요 |
| 라이선스 만료 처리 (`expiry_check_wrapper.dart`, `exit(0)` 호출) | 네이티브 프로세스 종료 | **웹은 만료 없이 계속 운영하기로 확정** — `kIsWeb`이면 만료 검사 자체를 건너뛰도록 분기 (별도 차단 화면 불필요) |
| `firebase_core` 등 신규 의존성 추가 | — | 추가 직후 `flutter build windows`/모바일 빌드로 **회귀 확인 필수** (의존성 추가가 기존 빌드에 영향을 줄 수 있음) |

### 7.1 웹 환경 성능 제약 — 순환/이중 교체 경로 탐색

`circular_path_finder.dart`, `dual_path_finder.dart`가 `compute()`로 경로
탐색을 백그라운드 isolate에서 돌리는데, **웹에는 진짜 isolate가 없어
`compute()`가 메인 스레드에서 그대로 실행**된다. 탐색 중 UI가 멈출 수
있으며, CLAUDE.md에 명시된 "1초 미만 실시간 시뮬레이션" 요건과 부딪힌다.

- 실제 교사 수 범위(2~5명 순환)에서 웹 빌드로 탐색 시간을 측정해 체감
  가능한 수준인지 먼저 확인
- 느리면 탐색 루프 사이에 `await Future.delayed(Duration.zero)`로 프레임을
  양보하는 방식으로 완화

## 8. Firebase 요금제 — Blaze(종량제)로 전환해도 무료로 쓸 수 있는가

**예, 가능합니다.** Blaze는 "선불 유료"가 아니라 **"무료 한도까지는
$0, 넘는 만큼만 과금"**되는 종량제(pay-as-you-go)입니다. 결제수단 등록은
필수지만, 사용량이 무료 한도 안에 있으면 청구 금액은 0원입니다.

### 왜 Blaze가 필요한가
2024년 10월 30일 이후 새로 만든 Firebase 프로젝트는 **Cloud Storage를
쓰려면 Blaze 요금제가 필수**입니다 (Spark/무료 요금제에서는 신규
프로젝트에 Storage 버킷 자체를 만들 수 없음). 공용 시간표 파일을 Storage에
두는 이상, 이 전환은 선택이 아니라 필수입니다.

### Blaze에서도 적용되는 무료 한도 (매월 자동 리셋)

| 항목 | 무료 한도 (Blaze에서도 동일하게 적용) | 이 앱 기준 체감 |
|---|---|---|
| Authentication (익명 로그인 포함) | 월간 활성 사용자 50,000명 | 교사 수십 명이면 전혀 문제 없음 |
| Firestore 저장 용량 | 1 GiB | 설정 문서 몇 개뿐이라 사실상 무제한급 |
| Firestore 일일 읽기/쓰기 | 읽기 50,000건 / 쓰기 20,000건 | 접속 시 가벼운 버전 조회 위주라 여유 큼 |
| Cloud Storage 저장 | 5 GB(월) | JSON 파일(수백 KB~수 MB) 기준 전혀 부담 없음 |
| Cloud Storage 네트워크 송신(다운로드) | 1 GB/일 (Google Cloud 일반 무료 티어 기준) | JSON 포맷으로 전환하면서 파일 크기가 더 작아져(수백 KB 수준이면) 하루 1,000회 이상 접속도 커버 가능 |

### 안전장치: 예산 알림(Budget Alert) 설정

- Google Cloud 콘솔의 **예산 및 알림** 메뉴에서 "$1" 같은 낮은 금액을
  기준으로 알림을 설정해 두면, 무료 한도를 넘기 시작하는 순간 이메일로
  통보받을 수 있다 (알림 자체는 무료 기능)
- 이 앱 사용 규모(학교 1곳)에서는 무료 한도를 넘길 가능성이 낮지만,
  "결제수단은 등록했지만 실제 과금은 0원"이라는 상태를 계속 확인하기 위한
  최소한의 안전장치로 권장

### 결론
결제수단을 등록해도 **학교 단위 사용 규모에서는 사실상 계속 무료**로
운영될 것으로 예상된다. 예산 알림만 설정해 두면, 혹시 사용량이 예상보다
크게 늘어나는 경우에도 과금되기 전에 미리 인지할 수 있다.

## 9. 단계별 작업 계획

1. **0단계 — 사전 리스크 점검 (신규)**
   - 지금 상태에서 `flutter build web` 실행 → 컴파일 에러 전수 목록 확보 (5.1절)
   - 이 목록을 바탕으로 조건부 import 분리 대상 파일 범위를 재확정
2. **1단계 — 로컬 DB/저장소 웹 지원**
   - `sqflite_common_ffi_web` 패키지 추가, `dart run sqflite_common_ffi_web:setup` 실행
   - `timetable_database.dart`, `storage_service.dart`, `timetable_storage_service.dart`를
     조건부 import 구조로 분리 (5·6장 참고)
   - `firebase_core` 등 신규 의존성 추가 직후 `flutter build windows`로 회귀 확인
   - 웹에서 개인 데이터 CRUD 동작 확인 (`flutter run -d chrome`)
3. **2단계 — 인증(접속자/관리자/마스터, 웹 전용)**
   - Firebase 프로젝트 생성 (Firestore + Storage + Anonymous Auth 활성화),
     Blaze 요금제 전환 + 예산 알림 설정 (8장)
   - `config/public`, `config/auth`, `config/sharedTimetable` 문서 스키마 생성,
     초기 비밀번호 해시 값 부트스트랩(최초 배포 시 수동으로 1회 입력)
   - 마스터 ID+비밀번호 상수 추가 (4.2절)
   - 접속 비밀번호 화면 + 관리자 모드 진입 화면(평소 비밀번호 입력 +
     마스터 로그인 보조 폼) + 관리자용 "접속자 비밀번호/안내 메시지 변경" 화면 구현
   - 로그인 상태 로컬 저장(세션 유지) 구현
4. **3단계 — 공용 시간표 동기화 (JSON 방식)**
   - 관리자 측: 로컬 `Lesson` 데이터를 JSON으로 직렬화해 Storage 업로드 +
     `config/sharedTimetable.version` 증가 (업로드 전 버전 증가 순서, 3.3절)
   - 클라이언트 측: 버전 비교 후 JSON 다운로드 → 로컬 SQLite에 반영 (3.2·3.3절)
   - Storage CORS 설정 적용 (Cloudflare Pages 도메인에서 Storage 접근 허용)
   - Firestore/Storage 규칙 적용 및 검증 (4.4절)
5. **4단계 — 파일 I/O 기반 기능 웹 대응**
   - PDF 내보내기: `printing` 패키지의 웹 지원 기능(`sharePdf`)으로 전환
   - 엑셀 내보내기: 브라우저 다운로드(Blob) 방식으로 전환
   - 엑셀 업로드: 죽은 `kIsWeb` 분기 정리, 실제 동작 경로로 통합
   - 클립보드 붙여넣기: 웹에서는 기능 제한 고지 또는 Async Clipboard API로 대체
   - 라이선스 만료 처리: `kIsWeb`일 때 만료 검사 건너뛰도록 분기 (계속 운영 확정, 7장 표 참고)
6. **5단계 — 호스팅 및 배포 (Cloudflare Pages)**
   - GitHub Actions에서 `flutter build web` 실행 후 `wrangler pages deploy
     build/web`로 배포 (Cloudflare Pages 자체 빌드 이미지에는 Flutter SDK 없음)
   - `--base-href`, 캐시 헤더(`_headers`: `index.html`/서비스워커는
     no-cache, 해시가 붙은 정적 자산은 immutable) 설정
   - 마스터/초기 비밀번호 등 민감 값은 `--dart-define` + CI Secret으로 주입
     (소스코드에 직접 커밋하지 않음)
   - Firebase 프로젝트의 승인된 도메인(Authentication) 목록에 Cloudflare
     Pages 배포 도메인 추가

## 10. 리스크 및 트레이드오프

- **쓰기 권한이 느슨함**: 익명 로그인만 되면 Firestore/Storage 쓰기가
  가능해, 작정한 사람은 비밀번호 없이도 데이터를 바꿀 수 있음 → 요구사항상
  허용된 리스크 (단, 비밀번호 평문 노출은 4장에서 별도로 막음)
- **JSON 변환 작업이 신규 공정으로 추가됨**: 기존에 "파일만 옮기면 된다"고
  낙관했던 공용 시간표 동기화가, 이제는 데이터 추출→직렬화→역직렬화→로컬
  DB 반영까지 포함하는 작은 규모의 신규 기능 개발이 됨 (3장)
- **PC/모바일 "동작 무변경"은 유지되지만 "코드 무변경"은 아님**: 공용
  파일 분리 작업 자체가 리그레션 위험을 수반하므로, 분리 직후 PC/모바일
  빌드·동작 테스트가 필수 공정으로 들어감 (9장 1단계)
- **동시 편집 미지원**: 관리자가 2명 이상 동시에 수정하면 나중에 저장한
  쪽이 이전 변경을 덮어씀 (요구사항상 허용된 범위, 백업/버전 관리 불필요로 확정)
- **PC/모바일과 웹은 완전히 분리된 별도 도구**: "정본" 개념 자체가 없음 —
  모바일/PC와 웹은 서로 동기화되지 않는 독립된 두 시스템으로 운영하기로
  확정 (11장). 따라서 "불일치"는 리스크가 아니라 의도된 설계이며, 교사
  대상 공지도 "둘은 원래 다른 시스템"이라는 점만 안내하면 충분함
- **웹 성능 제약**: `compute()` 기반 경로 탐색이 웹에서는 메인 스레드
  실행이라 UI 프리즈 가능성 있음 (7.1절)
- **브라우저 저장소 휘발성**: 요구사항상 허용되었지만, 생각보다 자주
  (iOS Safari 7일 미사용 등) 발생할 수 있어 안내 문구 고지 권장 (4.5절)

## 11. 결정 대기 사항

- [x] 호스팅: Cloudflare Pages 사용 확정 (단, 빌드는 GitHub Actions 경유)
- [x] 공용 시간표 동기화 범위: 웹 전용, PC/모바일 미적용 확정
- [x] 보안 수준: 편의성 우선 + 비밀번호 평문 노출 방지 최소 조치 확정
- [x] 기존 로컬 데이터 호환성: 불필요 확정
- [x] 백업/버전 관리: 불필요 확정
- [x] 공용 시간표 전송 방식: SQLite 파일 통째 전송 → **JSON 방식으로 변경 확정**
- [x] Firebase 요금제: Blaze(결제수단 등록) + 예산 알림으로 무료 운영 확정
- [x] 관리자 비밀번호 분실 대비: 마스터 ID+비밀번호 조합으로 강화 확정
- [x] Cloudflare Pages 프로젝트: **`class-swap`로 생성 완료** → 기본 도메인
      `class-swap.pages.dev` 사용 (커스텀 도메인 연결은 추후 필요 시 진행)
- [x] 공용 시간표(웹)와 PC/모바일 관계: **완전히 분리된 별도 시스템으로
      운영, 동기화·정본 개념 불필요** 확정 — 교사 안내도 "서로 다른
      독립 도구"라는 점만 전달하면 됨
- [x] 웹 버전의 라이선스 만료 정책: **만료 없이 계속 운영** 확정 (PC/모바일과
      달리 `expiry_check_wrapper.dart`의 만료 체크 로직을 웹에서는 적용하지
      않음 — `kIsWeb`이면 만료 검사 자체를 건너뛰도록 구현, 7장 표 반영)
- [ ] Firebase 프로젝트 생성 주체/계정 (학교 계정 vs 개인 계정) — 결제수단 등록 가능 여부 포함
- [ ] 마스터 ID·비밀번호 실제 값 (코드에 고정될 값)
- [ ] 관리자 비밀번호 초기값, 접속자 비밀번호 초기값
- [ ] 로그인 안내 메시지 초기 문구
