# DynaNotch — CLAUDE.md

macOS 노치 영역을 아이폰 다이나믹 아일랜드처럼 활용하는 백그라운드 상주 앱.

---

## 프로젝트 개요

- **앱 이름**: DynaNotch
- **플랫폼**: macOS 12.0+, MacBook with notch (2021~)
- **개발 언어**: Swift
- **UI 프레임워크**: AppKit + SwiftUI 혼용
- **애니메이션**: Core Animation (spring)
- **배포 형태**: 메뉴바 상주 앱 (.app), LSUIElement = YES

---

## 기술 스택

| 기능 | 사용 기술 |
|------|-----------|
| 노치 오버레이 윈도우 | NSWindow (borderless, floating level) |
| 음악 정보 | MediaRemote framework (private) |
| 기온 표시 | Open-Meteo API |
| 슬랙 / 카톡 알림 감지 | UNUserNotificationCenter |
| 터미널 상태 감지 | Shell process 감지 |
| 볼륨 / 밝기 조절 | CoreAudio / IOKit |
| 스크린샷 감지 | CGEventTap (Cmd+Shift+3/4/5 후킹) |
| 파일 저장 | FileManager |

---

## UI 구조

```
기본 상태:
[LEFT pill] ●●●●●●●(노치)●●●●●●● [RIGHT pill]

확장 상태 (hover 시 좌우 + 아래로 확장):
┌──────────────────────────────────────┐
│      ●●●●●(노치)●●●●●               │
│  🎵 Blinding Lights · The Weeknd     │
│  ████████░░  ☁️ 18°  💬 3           │
└──────────────────────────────────────┘
```

### 왼쪽 Pill — 상태 표시
| 상황 | 표시 내용 |
|------|-----------|
| 음악 재생 중 | 앨범아트 (원형) + 곡명 |
| 터미널 작업 중 | ⚙️ 실행 중 표시 |
| 터미널 완료 | ✅ / ❌ 결과 표시 |
| 스크린샷 감지 | 📸 폴더 선택 UI |
| idle | 작은 기본 pill 유지 |

### 오른쪽 Pill — 정보 표시
| 상황 | 표시 내용 |
|------|-----------|
| 슬랙 알림 | 🔔 채널명 + 메시지 미리보기 |
| 카톡 알림 | 💬 발신자 + 메시지 미리보기 |
| 기본 상태 | ☁️ 현재 기온 |

---

## 인터랙션

| 동작 | 반응 |
|------|------|
| hover | 노치 기준 좌우 + 아래로 확장 (spring animation) |
| 상하 드래그 | 볼륨 / 밝기 조절 |
| hover 해제 | 자동으로 pill 상태로 축소 |
| 스크린샷 단축키 | 폴더 선택 UI로 즉시 확장 |

---

## 스크린샷 저장 기능

- **감지 방식**: CGEventTap으로 Cmd+Shift+3/4/5 후킹
- **동작**: 감지 즉시 노치 확장 → 즐겨찾기 폴더 목록 표시
- **타임아웃**: 5초 내 미선택 시 기본 폴더로 자동 저장
- **폴더 관리**: 설정 UI에서 사용자가 직접 폴더 추가/삭제/기본 지정
- **미리보기**: 확장 UI에 스크린샷 썸네일 표시

---

## 개발 Phase

| Phase | 내용 | 브랜치 |
|-------|------|--------|
| 1 | NSWindow 오버레이 + pill UI + 확장 애니메이션 | feature/pill-ui |
| 2 | 음악 재생 모듈 (MediaRemote) | feature/music-module |
| 3 | 슬랙 / 카톡 알림 모듈 | feature/notification |
| 4 | 기온 표시 (Open-Meteo API) | feature/weather |
| 5 | 터미널 상태 모듈 | feature/terminal |
| 6 | 스크린샷 감지 + 폴더 저장 UI | feature/screenshot |
| 7 | 설정 UI + 메뉴바 아이콘 + 배포 | feature/settings |

---

## 브랜치 전략

```
main        → 배포용 (안정 버전)
dev         → 개발 통합 브랜치
feature/*   → 기능별 작업 브랜치
```

---

## 주요 기술 고려사항

- **노치 좌표**: `NSScreen.main?.auxiliaryTopRightArea` 로 노치 영역 감지
- **클릭 통과**: `ignoresMouseEvents` 를 상황에 따라 동적으로 전환
- **Mission Control 대응**: 스페이스 전환 시 윈도우 유지 설정 필요
- **다크모드 융합**: 배경을 완전 블랙 (`#000000`) 으로 맞춰 노치와 자연스럽게 융합
- **MediaRemote**: private framework이므로 헤더 직접 선언 필요
- **CGEventTap**: Accessibility 권한 필요 (Info.plist 설정)

---

## 현재 진행 상태

- [x] GitHub 레포 생성 (https://github.com/parksw0802/DynaNotch)
- [x] Xcode 프로젝트 초기화
- [x] main / dev / feature/pill-ui 브랜치 생성
