# 릴리스 가이드

## 새 버전 배포 절차

### 1. 사전 준비 (최초 1회)

```powershell
# GitHub CLI 설치 후 인증
winget install GitHub.cli
gh auth login
```

### 2. 새 버전 릴리스

```powershell
# 패치 (버그 수정)
.\release.ps1 -Version "1.0.1" -Notes "버그 수정"

# 마이너 (기능 추가)
.\release.ps1 -Version "1.1.0" -Notes "추천 알고리즘 개선"

# 노트 자동 생성 (이전 태그 이후 커밋 메시지로)
.\release.ps1 -Version "1.0.2"

# 빌드 스킵 (기존 APK 재사용)
.\release.ps1 -Version "1.0.3" -SkipBuild

# 초안(draft)으로 만들기
.\release.ps1 -Version "1.1.0-rc1" -Draft
```

### 3. 스크립트가 자동으로 수행하는 작업

1. `pubspec.yaml`의 `version:` 업데이트
2. `flutter pub get` + `flutter build apk --release`
3. APK를 `build/release/lsy-m-lotto-<version>.apk` 로 복사
4. git 커밋 (`chore: bump version to ...`)
5. `v<version>` 태그 생성 + push
6. GitHub Release 생성 + APK 업로드

## 앱의 업데이트 체크 동작

- **자동**: 앱 시작 시 [home_screen.dart:_checkForUpdate](lib/screens/home_screen.dart) 가 GitHub Releases API 호출
- **수동**: 헤더의 ⬇️ 아이콘 탭
- 새 버전 발견시 다이얼로그 표시 → "업데이트" 누르면 APK URL을 외부 브라우저로 오픈

## 버전 번호 규칙 (Semantic Versioning)

- `MAJOR.MINOR.PATCH` (예: 1.2.3)
- **MAJOR**: 기존과 호환 안 되는 큰 변경
- **MINOR**: 기능 추가 (하위 호환)
- **PATCH**: 버그 수정만

태그는 `v` 접두사 사용: `v1.2.3`
