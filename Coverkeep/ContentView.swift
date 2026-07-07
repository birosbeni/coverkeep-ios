import SwiftUI

/// Slice 0 placeholder. Slice 1 replaces this with fast item entry and the
/// "you have these rights until these dates" moment.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No items yet",
                systemImage: "archivebox",
                description: Text("Add a purchase to see your warranty rights and deadlines.")
            )
            .navigationTitle("Coverkeep")
        }
    }
}

#Preview {
    ContentView()
}
