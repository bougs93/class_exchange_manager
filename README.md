# 교사용 시간표 교체 프로그램

교사들의 시간표 교체 업무를 효율화하고 자동화하는 Flutter 애플리케이션입니다.

## 📋 프로젝트 개요

병가, 출장, 연수 등으로 인한 수업 교체를 신속하게 처리할 수 있는 도구로, Excel 파일을 읽어 시간표를 표시하고 1:1 또는 순환 교체를 지원합니다.

## ✨ 주요 기능

- **Excel 파일 호환**: 기존 xlsx 형태 시간표 파일 완전 지원
- **1:1 교체**: 두 교사 간 직접 시간 교체
- **순환 교체**: 2~5명이 순환하며 교체 지원
- **실시간 시각화**: 교체 가능한 시간을 색상으로 표시
- **문서 생성**: PDF 결보강 계획서 자동 생성
- **QR코드**: 교체 정보 전달을 위한 QR코드 생성
- **오프라인 우선**: 인터넷 없이 모든 기능 사용 가능

## 🎯 대상 플랫폼

- **모바일**: Android, iOS
- **데스크톱**: Windows
- **위젯**: Windows 시스템 트레이 위젯 (선택사항)

## 🛠 기술 스택

- **프레임워크**: Flutter
- **상태 관리**: Riverpod
- **데이터베이스**: SQLite
- **UI 그리드**: flutter_layout_grid
- **파일 처리**: Excel 읽기, PDF 생성

## 📁 프로젝트 구조

```
lib/
├── models/           # 데이터 모델
├── providers/        # Riverpod 상태 관리
├── services/         # 비즈니스 로직
├── repositories/     # 데이터 접근
├── ui/              # UI 컴포넌트
│   ├── screens/     # 화면
│   └── widgets/     # 위젯
└── utils/           # 유틸리티
```

## 🚀 시작하기

### 필수 요구사항

- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / VS Code

### 설치 및 실행

1. 저장소 클론
```bash
git clone [repository-url]
cd class_exchange_manager
```

2. 의존성 설치
```bash
flutter pub get
```

3. 앱 실행
```bash
flutter run
```

## 📖 사용법

1. **Excel 파일 로드**: 기존 시간표 Excel 파일을 선택
2. **시간표 확인**: 교사별 시간표를 그리드 형태로 표시
3. **교체 실행**: 교체하고 싶은 시간을 클릭하여 옵션 확인
4. **문서 생성**: 교체 완료 후 PDF 문서 자동 생성

## 🔧 개발 계획

### Phase 1: 핵심 기능 (4-6주)
- [x] 프로젝트 설정 및 설계
- [ ] Excel 파일 파싱
- [ ] 시간표 그리드 UI
- [ ] 1:1 교체 기능

### Phase 2: 고급 기능 (4-6주)
- [ ] 순환 교체 알고리즘
- [ ] PDF 문서 생성
- [ ] 개인 시간표 관리

### Phase 3: 최적화 (2-4주)
- [ ] Windows 위젯
- [ ] 성능 최적화
- [ ] 사용자 테스트

## 📚 문서

- [요구사항 정의서](docs/requirements.md)
- [설계 문서](docs/design.md)
- [글로벌 규칙](docs/global_rules.md)

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 지원

프로젝트에 대한 질문이나 문제가 있으시면 이슈를 생성해 주세요.

---

**개발 상태**: 🚧 개발 중 (Phase 1)