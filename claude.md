# KitApp - Claude Code 指示書

## コミットルール

### 粒度
- **1コミット = 1つの論理的な変更**
- ファイル追加とそのファイルを使う変更は分ける
- リファクタリングと機能追加は混ぜない
- 動作する状態でコミットする（ビルドが通る）

### メッセージ形式
- **コミットメッセージは日本語で書く**
- 1行目: 変更内容の要約（50文字以内）
- 空行
- 本文: 変更の詳細（箇条書き推奨）

```
機能追加: NavigationViewStateを作成

- NavPhase enumを追加
- ViewState構造体を定義
- 表示用の計算プロパティを追加
```

### コミット前の確認
各コミットの前に以下を確認：
1. 変更内容が1つの目的に絞られているか
2. ビルドが通るか
3. 不要な変更が含まれていないか

### レビュー依頼
**コミット作成後、次の作業に進む前に必ずユーザーにレビューを依頼する**

```
コミット完了: [コミットメッセージ]
変更内容:
- [変更点1]
- [変更点2]

次のステップに進んでよいですか？
```

## アーキテクチャ: ViewState, View, Store

### 構造
```
View (UI描画)
  ↓ store.send(action)
Store (状態管理 + ビジネスロジック)
  ↓ @Published state
ViewState (表示用データ)
```

### ファイル配置
```
KitApp/
├── App/
├── Models/
├── Store/
│   ├── NavigationStore.swift
│   ├── NavigationAction.swift
│   └── NavigationViewState.swift
├── Services/
│   ├── ARSessionService.swift
│   └── RouteRepository.swift
└── Views/
    └── Components/
```

## リファクタリング手順

### Phase 1: 基盤作成
- [x] Step 1.1: NavigationViewState の作成
- [x] Step 1.2: NavigationAction の作成
- [x] Step 1.3: NavigationStore の雛形作成

### Phase 2: サービス層の抽出
- [x] Step 2.1: NavigationConfig の作成（マジックナンバー集約）
- [x] Step 2.2: RouteRepository の作成（データ永続化）
- [x] Step 2.3: ARSessionService の作成（AR操作の抽出）

### Phase 3: View のリファクタリング
- [x] Step 3.1: ContentView を Store に接続
- [x] Step 3.2: ARSceneView を Store に接続
- [x] Step 3.3: 旧 Binding の削除

### Phase 4: コンポーネント分割
- [ ] Step 4.1: StatusBarView の抽出
- [ ] Step 4.2: RecordingInfoView の抽出
- [ ] Step 4.3: ControlButtonsView の抽出
- [ ] Step 4.4: RouteListSheet の抽出

### Phase 5: クリーンアップ
- [ ] Step 5.1: 未使用コードの削除
- [ ] Step 5.2: コード重複の解消
- [ ] Step 5.3: エラーハンドリングの改善
