//
//  RouteRepository.swift
//  KitApp
//
//  ルートデータの永続化を担当するリポジトリ
//

import Foundation
import SwiftData

// MARK: - RouteRepository

/// ルートデータの保存・取得・削除を行うリポジトリ
@MainActor
final class RouteRepository {

    // MARK: - Properties

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    /// 保存済みルートを全て取得（作成日時の降順）
    func fetchAllRoutes() -> [NavRoute] {
        let descriptor = FetchDescriptor<NavRoute>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ ルート取得エラー: \(error)")
            return []
        }
    }

    /// 保存済みルートをRouteListItem形式で取得
    func fetchRouteListItems() -> [RouteListItem] {
        fetchAllRoutes().map { route in
            RouteListItem(
                id: route.id,
                name: route.name,
                totalDistance: route.totalDistance,
                moveCount: route.moveCount,
                eventCount: route.eventCount,
                createdAt: route.createdAt
            )
        }
    }

    /// IDでルートを取得
    func fetchRoute(by id: UUID) -> NavRoute? {
        let descriptor = FetchDescriptor<NavRoute>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ ルート取得エラー: \(error)")
            return nil
        }
    }

    // MARK: - Save

    /// 新しいルートを保存
    func saveRoute(
        items: [RouteItem],
        worldMapData: Data?,
        startAnchorID: UUID?,
        startHeading: Float
    ) -> Result<String, NavigationError> {
        let routeName = "Route_\(Date().formatted(.dateTime.month().day().hour().minute()))"

        let route = NavRoute(
            name: routeName,
            items: items,
            worldMapData: worldMapData,
            startAnchorID: startAnchorID,
            startHeading: startHeading
        )

        modelContext.insert(route)

        do {
            try modelContext.save()
            let mapStatus = worldMapData != nil ? "WorldMap付き" : "WorldMapなし"
            print("✅ ルート保存完了: \(routeName), items: \(items.count), \(mapStatus)")
            return .success(routeName)
        } catch {
            print("❌ ルート保存エラー: \(error)")
            return .failure(.saveFailed(error.localizedDescription))
        }
    }

    // MARK: - Delete

    /// 指定したインデックスのルートを削除
    func deleteRoutes(at indexSet: IndexSet, from routes: [NavRoute]) {
        for index in indexSet {
            if index < routes.count {
                modelContext.delete(routes[index])
            }
        }

        do {
            try modelContext.save()
            print("✅ ルート削除完了")
        } catch {
            print("❌ ルート削除エラー: \(error)")
        }
    }

    /// IDでルートを削除
    func deleteRoute(by id: UUID) {
        guard let route = fetchRoute(by: id) else { return }

        modelContext.delete(route)

        do {
            try modelContext.save()
            print("✅ ルート削除完了: \(route.name)")
        } catch {
            print("❌ ルート削除エラー: \(error)")
        }
    }
}
