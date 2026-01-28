# 프로젝트 목표: 실시간 딥페이크 공격 시뮬레이터(MVP)로의 완전 전환

## 마감 기한: 2026년 2월 3일 (긴급)

### 1. 현황 및 변경 사유

- 기존 구조: 파이썬 서버로 실시간 페이스스왑 데이터를 전송/수신하는 방식이었으나 성능 이슈로 실패함.
- 변경 구조: 사전 제작된 딥페이크 영상을 활용한 '심리스 트랙 교체(Track Switching)' 방식으로 전면 리팩토링함.

### 2. 핵심 아키텍처 (Canvas Pipeline)

- 모든 영상 소스(카메라/파일)는 사용자에게 직접 렌더링되지 않고, 'Hidden Canvas'를 거쳐야 함.
- Canvas 위에서 실시간 필터(Mosaic, Beauty)가 픽셀 단위로 적용됨.
- `canvas.captureStream()`을 통해 추출된 가공 스트림이 WebRTC를 통해 아이폰(Target)으로 송출됨.

### 3. 기능 요구 사항

- **Deepfake Toggle**: 버튼 클릭 시 카메라 트랙과 딥페이크 영상 트랙이 `replaceTrack()`으로 즉시 교체됨.
- **Filter Toggles**: Mosaic, Beauty 필터는 각각 독립적인 토글(On/Off) 버튼으로 작동함.
- **상태 유지**: 카메라 모드에서 필터 적용 중 딥페이크로 전환해도 필터 상태가 유지되어야 함.

### 4. 기술 스택

- 상태 관리: Flutter Riverpod
- 통신: flutter_webrtc, socket_io_client
