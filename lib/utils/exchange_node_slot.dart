/// 순환·2중 교체의 노드별 확정 날짜([ExchangeHistoryItem.nodeDates])를 찾을 때
/// 쓰는 키 (S5.6).
///
/// 교사 이름을 포함하지 않는다 — [ExchangeCellDates.forItem]의 기존 계약이
/// 이미 "칸의 날짜는 그 칸이 차지한 노드(요일·교시)의 날짜와 같다, 누가
/// 앉든 상관없다"이기 때문이다(1:1의 4칸 매핑이 이미 이 규칙을 따른다).
/// 교사를 키에 넣으면 순환 교체에서 한 노드가 다른 행의 source이자 target
/// 양쪽으로 등장할 때 같은 칸인데 다른 키를 갖게 되어 동기화가 깨진다.
///
/// [dayName]은 `ExchangeNode.day`와 같은 형식('월'~'금')이어야 한다.
String nodeSlotKey(String dayName, int period) => '$dayName|$period';
