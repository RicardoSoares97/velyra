import Foundation
import SwiftUI

@MainActor
final class StremioImportViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case creatingLink
    case awaitingAuthorization(StremioLinkCode)
    case validating
    case preview(StremioImportPreview)
    case complete(importedCount: Int)
    case failed(message: String)
  }

  @Published private(set) var state: State = .idle

  private let service: any StremioAddonImportServing
  private let validator: any AddonManifestValidating
  private var task: Task<Void, Never>?
  private var operationID: UUID?

  init(
    service: any StremioAddonImportServing = StremioAddonImportService(),
    validator: any AddonManifestValidating = AddonClient()
  ) {
    self.service = service
    self.validator = validator
  }

  deinit {
    task?.cancel()
  }

  func start(installed: [String]) {
    task?.cancel()
    let operationID = UUID()
    self.operationID = operationID
    state = .creatingLink
    let session = StremioImportSession(service: service)

    task = Task { [weak self, service, session] in
      do {
        let link = try await service.createLink()
        try Task.checkCancellation()
        guard self?.operationID == operationID else { return }
        self?.state = .awaitingAuthorization(link)

        let descriptors = try await session.fetchDescriptors(link: link)
        try Task.checkCancellation()
        guard self?.operationID == operationID else { return }
        self?.state = .validating

        let initial = StremioAddonImportPlanner.candidates(
          from: descriptors,
          installed: installed
        )
        let validated = await self?.validate(initial) ?? []
        try Task.checkCancellation()
        guard self?.operationID == operationID else { return }
        self?.state = .preview(StremioImportPreview(candidates: validated))
      } catch is CancellationError {
        guard self?.operationID == operationID else { return }
        self?.state = .idle
      } catch {
        guard self?.operationID == operationID else { return }
        let message =
          (error as? LocalizedError)?.errorDescription
          ?? String(localized: "stremio.error.generic")
        self?.state = .failed(message: message)
      }
    }
  }

  func toggleSelection(candidateID: String) {
    guard case .preview(var preview) = state,
      let index = preview.candidates.firstIndex(where: { $0.id == candidateID }),
      preview.candidates[index].status == .new
    else { return }
    preview.candidates[index].isSelected.toggle()
    state = .preview(preview)
  }

  func confirm(existing: [String]) -> [String] {
    guard case .preview(let preview) = state else { return existing }
    let merged = StremioAddonImportPlanner.merging(
      existing: existing,
      candidates: preview.candidates
    )
    state = .complete(importedCount: merged.count - existing.count)
    return merged
  }

  func cancel() {
    operationID = nil
    task?.cancel()
    task = nil
    if case .complete = state {
      return
    }
    state = .idle
  }

  private func validate(
    _ candidates: [StremioAddonCandidate]
  ) async -> [StremioAddonCandidate] {
    var result = candidates
    let indices = candidates.indices.filter {
      candidates[$0].status == .new && candidates[$0].manifestURL != nil
    }

    for batchStart in stride(from: 0, to: indices.count, by: 3) {
      let batch = Array(indices[batchStart..<min(batchStart + 3, indices.count)])
      let validator = self.validator

      let validations = await withTaskGroup(
        of: (Int, AddonManifest?).self,
        returning: [(Int, AddonManifest?)].self
      ) { group in
        for index in batch {
          guard let url = candidates[index].manifestURL else { continue }
          group.addTask {
            let manifest = try? await validator.manifest(from: url)
            return (index, manifest)
          }
        }

        var values: [(Int, AddonManifest?)] = []
        for await value in group {
          values.append(value)
        }
        return values
      }

      for (index, manifest) in validations {
        guard let manifest else {
          result[index].status = .incompatible(reason: .unreachable)
          result[index].isSelected = false
          continue
        }
        guard manifest.id == result[index].manifest.id else {
          result[index].status = .incompatible(reason: .manifestMismatch)
          result[index].isSelected = false
          continue
        }
        result[index].manifest = manifest
      }
    }

    return result
  }
}
