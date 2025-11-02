# 교체 리스트 데이터 구조 문서

## 목차

1. [개요](#개요)
2. [데이터 저장 구조](#데이터-저장-구조)
3. [ExchangeHistoryItem 구조](#exchangehistoryitem-구조)
4. [ExchangePath 구조](#exchangepath-구조)
5. [ExchangeNode 구조](#exchangenode-구조)
6. [JSON 스키마](#json-스키마)
7. [파일 저장 형식](#파일-저장-형식)
8. [데이터 접근 방법](#데이터-접근-방법)
9. [사용 예시](#사용-예시)
10. [주의사항](#주의사항)

---

## 개요

교체 리스트(`_exchangeList`)는 수업 교체 작업의 모든 히스토리를 저장하는 데이터 구조입니다. 각 교체 실행마다 하나의 `ExchangeHistoryItem` 객체가 생성되어 리스트에 추가됩니다.

### 기본 정보

- **변수명**: `_exchangeList`
- **타입**: `List<ExchangeHistoryItem>`
- **저장 위치**: 메모리 (런타임), `exchange_list.json` (영구 저장)
- **접근 방식**: `ExchangeHistoryService.getExchangeList()` 메서드를 통해 공개 접근

### 주요 특징

- 모든 교체 이력을 영구 보관
- JSON 형식으로 직렬화/역직렬화 지원
- 교체 타입별로 구조가 다른 `ExchangePath` 지원
- 메타데이터 및 사용자 입력(메모, 태그) 보관
- 되돌리기 상태 추적 가능

---

## 데이터 저장 구조

### 메모리 구조

```dart
// ExchangeHistoryService 내부
final List<ExchangeHistoryItem> _exchangeList = [];
```

### 파일 저장 구조

- **파일명**: `exchange_list.json`
- **위치**: 애플리케이션의 로컬 저장소
- **형식**: JSON 배열
- **인코딩**: UTF-8

---

## ExchangeHistoryItem 구조

`ExchangeHistoryItem`은 각 교체 실행을 나타내는 최상위 데이터 모델입니다.

### 클래스 정의

```dart
class ExchangeHistoryItem {
  final String id;                    // 고유 식별자
  final DateTime timestamp;            // 실행 시간
  final ExchangePath originalPath;     // 원본 교체 경로
  final String description;           // 사용자 친화적 설명
  final ExchangePathType type;         // 교체 타입 (enum)
  final Map<String, dynamic> metadata; // 추가 메타데이터
  final String? notes;                 // 사용자 메모 (nullable)
  final List<String> tags;             // 태그 목록
  bool isReverted;                     // 되돌리기 여부
}
```

### 필드 상세 설명

#### 1. `id` (String)

- **설명**: 교체 항목의 고유 식별자
- **형식**: `"{교체타입}_exchange_{타임스탬프}"`
- **생성 규칙**: 자동 생성 (수동 설정 가능)
- **예시**: 
  - `"one_to_one_exchange_20241201_143052_123"`
  - `"circular_exchange_3_20241201_143100_456"`

#### 2. `timestamp` (DateTime)

- **설명**: 교체 실행 시간
- **형식**: ISO 8601 형식의 DateTime 객체
- **예시**: `2024-12-01 14:30:52.123`

#### 3. `originalPath` (ExchangePath)

- **설명**: 교체 경로 정보를 담는 객체
- **타입**: `ExchangePath` 추상 클래스의 서브클래스
  - `OneToOneExchangePath` (1:1 교체)
  - `CircularExchangePath` (순환교체)
  - `ChainExchangePath` (연쇄교체)
  - `SupplementExchangePath` (보강교체)
- **중요**: 교체의 핵심 데이터를 포함

#### 4. `description` (String)

- **설명**: 사용자가 읽기 쉬운 교체 설명
- **예시**: 
  - `"홍길동 ↔ 김철수"` (1:1 교체)
  - `"순환교체 (3명)"` (순환교체)

#### 5. `type` (ExchangePathType)

- **설명**: 교체 타입을 나타내는 열거형
- **가능한 값**:
  - `oneToOne`: 1:1 교체
  - `circular`: 순환교체
  - `chain`: 연쇄교체
  - `supplement`: 보강교체

#### 6. `metadata` (Map<String, dynamic>)

- **설명**: 추가 메타데이터를 저장하는 맵
- **기본 포함 필드**:
  ```dart
  {
    'executionTime': '2024-12-01T14:30:52.123',  // ISO 8601 형식
    'userAction': 'manual',                      // 사용자 수동 실행
    'pathId': 'path_12345',                      // 교체 경로의 고유 ID
    'stepCount': 3                                // 순환교체 단계 수 (선택)
  }
  ```
- **확장 가능한 필드**:
  - `involvedTeachers`: 참여 교사 목록 (`List<String>`)
  - `involvedClasses`: 참여 학급 목록 (`List<String>`)
  - `involvedSubjects`: 참여 과목 목록 (`List<String>`)
  - `efficiencyScore`: 교체 효율성 점수 (`double`)

#### 7. `notes` (String?)

- **설명**: 사용자가 입력한 메모
- **타입**: nullable (선택적)
- **예시**: `"급하게 교체함"`, `"학부모 요청"`

#### 8. `tags` (List<String>)

- **설명**: 교체 항목에 대한 태그 목록
- **타입**: 문자열 리스트
- **예시**: `["급함", "중요", "검토필요"]`

#### 9. `isReverted` (bool)

- **설명**: 되돌리기 여부
- **기본값**: `false`
- **설명**: `true`이면 해당 교체가 취소된 상태

---

## ExchangePath 구조

`ExchangePath`는 교체 경로를 나타내는 추상 클래스로, 교체 타입에 따라 4가지 서브클래스가 있습니다.

### 공통 인터페이스

```dart
abstract class ExchangePath {
  String get id;                    // 경로의 고유 식별자
  String get displayTitle;          // 표시용 제목
  List<ExchangeNode> get nodes;     // 경로에 포함된 노드들
  ExchangePathType get type;        // 교체 경로의 타입
  bool get isSelected;              // 선택 상태
  void setSelected(bool selected);  // 선택 상태 설정
  String get description;          // 경로의 설명 텍스트
  int get priority;                 // 우선순위 (낮을수록 높음)
  Map<String, dynamic> toJson();    // JSON 직렬화
}
```

### 1. OneToOneExchangePath (1:1 교체)

**구조**:
```dart
class OneToOneExchangePath implements ExchangePath {
  ExchangeNode sourceNode;  // 선택된 원본 셀
  ExchangeNode targetNode;  // 교체 대상 셀
}
```

**설명**: 두 교사 간 단순 교체 (A ↔ B)

**예시**:
- 교사 A의 월요일 3교시 ↔ 교사 B의 월요일 5교시

### 2. CircularExchangePath (순환교체)

**구조**:
```dart
class CircularExchangePath implements ExchangePath {
  List<ExchangeNode> nodes;  // 3개 이상의 노드들
  int steps;                 // 순환 단계 수
}
```

**설명**: 3명 이상의 교사가 순환하여 교체 (A → B → C → A)

**예시**:
- 교사 A → 교사 B → 교사 C → 교사 A

### 3. ChainExchangePath (연쇄교체)

**구조**:
```dart
class ChainExchangePath implements ExchangePath {
  ExchangeNode nodeA;  // 첫 번째 교체의 원본
  ExchangeNode nodeB;  // 첫 번째 교체의 대상
  ExchangeNode node1;  // 두 번째 교체의 원본
  ExchangeNode node2;  // 두 번째 교체의 대상
  List<ChainStep> steps;  // 연쇄 단계 정보
}
```

**설명**: 두 개의 교체가 연쇄적으로 연결된 교체

**예시**:
- (A ↔ B) 이후 (B ↔ C)로 연결

### 4. SupplementExchangePath (보강교체)

**구조**:
```dart
class SupplementExchangePath implements ExchangePath {
  ExchangeNode sourceNode;  // 보강할 셀
  ExchangeNode targetNode;  // 보강할 교사
}
```

**설명**: 빈 시간대를 다른 교사가 보강하는 교체

---

## ExchangeNode 구조

`ExchangeNode`는 교체에 참여하는 각 시간표 셀을 나타냅니다.

### 클래스 정의

```dart
class ExchangeNode {
  final String teacherName;   // 교사명
  final String day;            // 요일 (월, 화, 수, 목, 금)
  final String? date;          // 날짜 (YYYY-MM-DD, nullable)
  final int period;            // 교시 (1-7)
  final String className;      // 학급명 (1-1, 2-3 등)
  final String subjectName;    // 과목명 (수학, 국어 등)
}
```

### 필드 상세

| 필드명 | 타입 | 필수 | 설명 | 예시 |
|--------|------|------|------|------|
| `teacherName` | `String` | ✅ | 교사명 | `"홍길동"` |
| `day` | `String` | ✅ | 요일 | `"월"`, `"화"`, `"수"`, `"목"`, `"금"` |
| `date` | `String?` | ❌ | 날짜 (YYYY-MM-DD) | `"2024-12-01"` |
| `period` | `int` | ✅ | 교시 번호 | `1`, `2`, `3`, ..., `7` |
| `className` | `String` | ✅ | 학급명 | `"1-1"`, `"2-3"` |
| `subjectName` | `String` | ✅ | 과목명 | `"수학"`, `"국어"`, `"영어"` |

### 고유 식별자

```dart
String get nodeId => '${teacherName}_${day}_${period}교시_$className';
```

**예시**: `"홍길동_월_3교시_1-1"`

---

## JSON 스키마

### 전체 스키마

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "array",
  "items": {
    "$ref": "#/definitions/ExchangeHistoryItem"
  },
  "definitions": {
    "ExchangeHistoryItem": {
      "type": "object",
      "required": [
        "id",
        "timestamp",
        "type",
        "description",
        "metadata",
        "tags",
        "isReverted",
        "originalPath"
      ],
      "properties": {
        "id": {
          "type": "string",
          "description": "고유 식별자"
        },
        "timestamp": {
          "type": "string",
          "format": "date-time",
          "description": "ISO 8601 형식의 실행 시간"
        },
        "type": {
          "type": "string",
          "enum": ["oneToOne", "circular", "chain", "supplement"],
          "description": "교체 타입"
        },
        "description": {
          "type": "string",
          "description": "사용자 친화적 설명"
        },
        "metadata": {
          "type": "object",
          "description": "추가 메타데이터"
        },
        "notes": {
          "type": ["string", "null"],
          "description": "사용자 메모"
        },
        "tags": {
          "type": "array",
          "items": {
            "type": "string"
          },
          "description": "태그 목록"
        },
        "isReverted": {
          "type": "boolean",
          "description": "되돌리기 여부"
        },
        "originalPath": {
          "oneOf": [
            { "$ref": "#/definitions/OneToOneExchangePath" },
            { "$ref": "#/definitions/CircularExchangePath" },
            { "$ref": "#/definitions/ChainExchangePath" },
            { "$ref": "#/definitions/SupplementExchangePath" }
          ]
        }
      }
    },
    "ExchangeNode": {
      "type": "object",
      "required": [
        "teacherName",
        "day",
        "period",
        "className",
        "subjectName"
      ],
      "properties": {
        "teacherName": { "type": "string" },
        "day": { "type": "string" },
        "date": { "type": ["string", "null"] },
        "period": { "type": "integer", "minimum": 1, "maximum": 7 },
        "className": { "type": "string" },
        "subjectName": { "type": "string" }
      }
    },
    "OneToOneExchangePath": {
      "type": "object",
      "required": ["type", "sourceNode", "targetNode"],
      "properties": {
        "type": { "type": "string", "const": "oneToOne" },
        "id": { "type": "string" },
        "sourceNode": { "$ref": "#/definitions/ExchangeNode" },
        "targetNode": { "$ref": "#/definitions/ExchangeNode" },
        "description": { "type": "string" },
        "priority": { "type": "integer" },
        "isSelected": { "type": "boolean" }
      }
    },
    "CircularExchangePath": {
      "type": "object",
      "required": ["type", "nodes"],
      "properties": {
        "type": { "type": "string", "const": "circular" },
        "id": { "type": "string" },
        "nodes": {
          "type": "array",
          "items": { "$ref": "#/definitions/ExchangeNode" },
          "minItems": 3
        },
        "steps": { "type": "integer" },
        "description": { "type": "string" },
        "priority": { "type": "integer" },
        "isSelected": { "type": "boolean" }
      }
    },
    "ChainExchangePath": {
      "type": "object",
      "required": ["type", "nodeA", "nodeB", "node1", "node2"],
      "properties": {
        "type": { "type": "string", "const": "chain" },
        "id": { "type": "string" },
        "nodeA": { "$ref": "#/definitions/ExchangeNode" },
        "nodeB": { "$ref": "#/definitions/ExchangeNode" },
        "node1": { "$ref": "#/definitions/ExchangeNode" },
        "node2": { "$ref": "#/definitions/ExchangeNode" },
        "chainDepth": { "type": "integer" },
        "steps": {
          "type": "array",
          "items": { "$ref": "#/definitions/ChainStep" }
        },
        "description": { "type": "string" },
        "priority": { "type": "integer" },
        "isSelected": { "type": "boolean" }
      }
    },
    "SupplementExchangePath": {
      "type": "object",
      "required": ["type", "sourceNode", "targetNode"],
      "properties": {
        "type": { "type": "string", "const": "supplement" },
        "id": { "type": "string" },
        "sourceNode": { "$ref": "#/definitions/ExchangeNode" },
        "targetNode": { "$ref": "#/definitions/ExchangeNode" },
        "description": { "type": "string" },
        "priority": { "type": "integer" },
        "isSelected": { "type": "boolean" }
      }
    }
  }
}
```

---

## 파일 저장 형식

### 파일 정보

- **파일명**: `exchange_list.json`
- **위치**: 애플리케이션의 로컬 저장소 디렉토리
- **인코딩**: UTF-8
- **형식**: JSON 배열 (최상위 레벨)

### 실제 저장 예시

```json
[
  {
    "id": "one_to_one_exchange_20241201_143052_123",
    "timestamp": "2024-12-01T14:30:52.123Z",
    "type": "oneToOne",
    "description": "홍길동 ↔ 김철수",
    "metadata": {
      "executionTime": "2024-12-01T14:30:52.123",
      "userAction": "manual",
      "pathId": "path_12345"
    },
    "notes": null,
    "tags": [],
    "isReverted": false,
    "originalPath": {
      "type": "oneToOne",
      "id": "path_12345",
      "sourceNode": {
        "teacherName": "홍길동",
        "day": "월",
        "date": null,
        "period": 3,
        "className": "1-1",
        "subjectName": "수학"
      },
      "targetNode": {
        "teacherName": "김철수",
        "day": "월",
        "date": null,
        "period": 5,
        "className": "2-2",
        "subjectName": "국어"
      },
      "description": "홍길동 ↔ 김철수",
      "priority": 1,
      "isSelected": false
    }
  },
  {
    "id": "circular_exchange_3_20241201_143100_456",
    "timestamp": "2024-12-01T14:31:00.456Z",
    "type": "circular",
    "description": "순환교체 (3명)",
    "metadata": {
      "executionTime": "2024-12-01T14:31:00.456",
      "userAction": "manual",
      "pathId": "path_67890",
      "stepCount": 3
    },
    "notes": "급하게 처리",
    "tags": ["급함", "중요"],
    "isReverted": false,
    "originalPath": {
      "type": "circular",
      "id": "path_67890",
      "nodes": [
        {
          "teacherName": "홍길동",
          "day": "월",
          "date": null,
          "period": 3,
          "className": "1-1",
          "subjectName": "수학"
        },
        {
          "teacherName": "김철수",
          "day": "화",
          "date": null,
          "period": 4,
          "className": "2-2",
          "subjectName": "국어"
        },
        {
          "teacherName": "이영희",
          "day": "수",
          "date": null,
          "period": 2,
          "className": "3-1",
          "subjectName": "영어"
        }
      ],
      "steps": 3,
      "description": "순환교체 (3명)",
      "priority": 1,
      "isSelected": false
    }
  }
]
```

---

## 데이터 접근 방법

### Dart/Flutter에서 접근

```dart
// ExchangeHistoryService 인스턴스 가져오기
final historyService = ExchangeHistoryService();

// 교체 리스트 조회
List<ExchangeHistoryItem> exchangeList = historyService.getExchangeList();

// 특정 항목 조회
ExchangeHistoryItem? item = historyService.getExchangeItem("item_id");

// 통계 정보 조회
Map<String, dynamic> stats = historyService.getExchangeListStats();

// 필터링
List<ExchangeHistoryItem> filtered = historyService.filterByType(ExchangePathType.oneToOne);

// 검색
List<ExchangeHistoryItem> searchResults = historyService.searchByDescription("홍길동");
```

### 다른 언어에서 접근

#### JavaScript/TypeScript

```javascript
// JSON 파일 읽기
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('exchange_list.json', 'utf8'));

// 교체 리스트 순회
data.forEach(item => {
  console.log(`ID: ${item.id}`);
  console.log(`Type: ${item.type}`);
  console.log(`Description: ${item.description}`);
  console.log(`Timestamp: ${item.timestamp}`);
  
  // 교체 경로 접근
  const path = item.originalPath;
  if (path.type === 'oneToOne') {
    console.log(`Source: ${path.sourceNode.teacherName}`);
    console.log(`Target: ${path.targetNode.teacherName}`);
  } else if (path.type === 'circular') {
    console.log(`Nodes: ${path.nodes.length}`);
  }
});
```

#### Python

```python
import json
from datetime import datetime

# JSON 파일 읽기
with open('exchange_list.json', 'r', encoding='utf-8') as f:
    exchange_list = json.load(f)

# 교체 리스트 순회
for item in exchange_list:
    print(f"ID: {item['id']}")
    print(f"Type: {item['type']}")
    print(f"Description: {item['description']}")
    print(f"Timestamp: {item['timestamp']}")
    
    # 교체 경로 접근
    path = item['originalPath']
    if path['type'] == 'oneToOne':
        print(f"Source: {path['sourceNode']['teacherName']}")
        print(f"Target: {path['targetNode']['teacherName']}")
    elif path['type'] == 'circular':
        print(f"Nodes: {len(path['nodes'])}")
```

#### Java

```java
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.File;
import java.util.List;
import java.util.Map;

// JSON 파일 읽기
ObjectMapper mapper = new ObjectMapper();
List<Map<String, Object>> exchangeList = mapper.readValue(
    new File("exchange_list.json"),
    List.class
);

// 교체 리스트 순회
for (Map<String, Object> item : exchangeList) {
    System.out.println("ID: " + item.get("id"));
    System.out.println("Type: " + item.get("type"));
    System.out.println("Description: " + item.get("description"));
    System.out.println("Timestamp: " + item.get("timestamp"));
    
    // 교체 경로 접근
    Map<String, Object> path = (Map<String, Object>) item.get("originalPath");
    String pathType = (String) path.get("type");
    
    if ("oneToOne".equals(pathType)) {
        Map<String, Object> sourceNode = (Map<String, Object>) path.get("sourceNode");
        Map<String, Object> targetNode = (Map<String, Object>) path.get("targetNode");
        System.out.println("Source: " + sourceNode.get("teacherName"));
        System.out.println("Target: " + targetNode.get("teacherName"));
    } else if ("circular".equals(pathType)) {
        List<Map<String, Object>> nodes = (List<Map<String, Object>>) path.get("nodes");
        System.out.println("Nodes: " + nodes.size());
    }
}
```

---

## 사용 예시

### 예시 1: 교체 통계 분석

```python
import json
from collections import Counter
from datetime import datetime

# JSON 파일 읽기
with open('exchange_list.json', 'r', encoding='utf-8') as f:
    exchange_list = json.load(f)

# 통계 수집
total_count = len(exchange_list)
type_counts = Counter(item['type'] for item in exchange_list)
reverted_count = sum(1 for item in exchange_list if item['isReverted'])
active_count = total_count - reverted_count

# 결과 출력
print(f"전체 교체: {total_count}개")
print(f"활성 교체: {active_count}개")
print(f"되돌린 교체: {reverted_count}개")
print("\n교체 타입별 통계:")
for exchange_type, count in type_counts.items():
    print(f"  {exchange_type}: {count}개")
```

### 예시 2: 특정 교사 교체 이력 조회

```python
import json

def get_exchanges_by_teacher(exchange_list, teacher_name):
    """특정 교사가 참여한 모든 교체를 반환"""
    results = []
    
    for item in exchange_list:
        path = item['originalPath']
        nodes = []
        
        # 교체 타입에 따라 노드 추출
        if path['type'] == 'oneToOne':
            nodes = [path['sourceNode'], path['targetNode']]
        elif path['type'] == 'circular':
            nodes = path['nodes']
        elif path['type'] == 'chain':
            nodes = [path['nodeA'], path['nodeB'], path['node1'], path['node2']]
        elif path['type'] == 'supplement':
            nodes = [path['sourceNode'], path['targetNode']]
        
        # 교사명이 포함된 노드 확인
        for node in nodes:
            if node['teacherName'] == teacher_name:
                results.append(item)
                break
    
    return results

# 사용 예시
with open('exchange_list.json', 'r', encoding='utf-8') as f:
    exchange_list = json.load(f)

hong_exchanges = get_exchanges_by_teacher(exchange_list, "홍길동")
print(f"홍길동 교사가 참여한 교체: {len(hong_exchanges)}개")
```

### 예시 3: JSON 파일 생성 (외부 프로그램에서)

```python
import json
from datetime import datetime

# 새 교체 항목 생성
new_exchange = {
    "id": "one_to_one_exchange_20241201_150000_789",
    "timestamp": datetime.now().isoformat() + "Z",
    "type": "oneToOne",
    "description": "이영희 ↔ 박민수",
    "metadata": {
        "executionTime": datetime.now().isoformat(),
        "userAction": "manual",
        "pathId": "path_new_123"
    },
    "notes": "외부 프로그램에서 생성",
    "tags": ["외부생성"],
    "isReverted": False,
    "originalPath": {
        "type": "oneToOne",
        "id": "path_new_123",
        "sourceNode": {
            "teacherName": "이영희",
            "day": "화",
            "date": None,
            "period": 2,
            "className": "3-1",
            "subjectName": "영어"
        },
        "targetNode": {
            "teacherName": "박민수",
            "day": "화",
            "date": None,
            "period": 4,
            "className": "4-2",
            "subjectName": "과학"
        },
        "description": "이영희 ↔ 박민수",
        "priority": 1,
        "isSelected": False
    }
}

# 기존 리스트 로드
with open('exchange_list.json', 'r', encoding='utf-8') as f:
    exchange_list = json.load(f)

# 새 항목 추가
exchange_list.append(new_exchange)

# 저장
with open('exchange_list.json', 'w', encoding='utf-8') as f:
    json.dump(exchange_list, f, ensure_ascii=False, indent=2)

print("교체 항목이 추가되었습니다.")
```

---

## 주의사항

### 1. 타입 안전성

- `originalPath`의 `type` 필드를 확인한 후 해당 타입의 구조에 맞게 접근해야 합니다.
- `null` 값이 가능한 필드(`date`, `notes`)는 항상 null 체크를 수행하세요.

### 2. 데이터 무결성

- ID는 고유해야 합니다. 중복된 ID를 생성하면 데이터 충돌이 발생할 수 있습니다.
- `timestamp`는 ISO 8601 형식으로 저장되며, 타임존 정보를 포함할 수 있습니다 (`Z` 또는 `+09:00`).

### 3. 버전 호환성

- JSON 구조가 변경될 수 있으므로, 프로그램에서 예외 처리를 구현하세요.
- 알 수 없는 필드는 무시하고 처리하는 것이 좋습니다.

### 4. 성능 고려사항

- 큰 교체 리스트의 경우, 전체를 메모리에 로드하는 대신 스트리밍 방식으로 처리하는 것을 고려하세요.
- 자주 조회하는 데이터는 캐싱을 고려하세요.

### 5. 파일 접근

- 파일을 수정할 때는 원본 파일을 백업하는 것이 좋습니다.
- 동시 접근 시 파일 잠금을 고려하세요.

### 6. 날짜/시간 처리

- `timestamp`는 UTC 기준으로 저장될 수 있으므로, 로컬 시간대 변환을 고려하세요.
- `date` 필드는 `YYYY-MM-DD` 형식의 문자열입니다.

---

## 참고 자료

### 관련 파일 경로

- **메인 서비스**: `lib/services/exchange_history_service.dart`
- **저장 서비스**: `lib/services/exchange_list_storage_service.dart`
- **데이터 모델**: 
  - `lib/models/exchange_history_item.dart`
  - `lib/models/exchange_path.dart`
  - `lib/models/exchange_node.dart`
  - `lib/models/one_to_one_exchange_path.dart`
  - `lib/models/circular_exchange_path.dart`
  - `lib/models/chain_exchange_path.dart`
  - `lib/models/supplement_exchange_path.dart`

### 문서 버전

- **버전**: 1.0.0
- **최종 업데이트**: 2024-12-01
- **작성자**: Class Exchange Manager Development Team

---

## 변경 이력

### Version 1.0.0 (2024-12-01)

- 초기 문서 작성
- 전체 데이터 구조 명세
- JSON 스키마 정의
- 다양한 언어별 사용 예시 추가

---

## 문의 및 지원

이 문서에 대한 질문이나 개선 사항이 있으면 프로젝트 관리자에게 문의하세요.

