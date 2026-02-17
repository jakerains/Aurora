import Foundation

struct GenerationQueueItem: Identifiable, Sendable {
    let id: UUID
    var job: GenerationJob
    var status: GenerationJobStatus
    var result: GenerationResult?
    var errorMessage: String?

    init(job: GenerationJob, status: GenerationJobStatus) {
        self.id = job.id
        self.job = job
        self.status = status
    }
}

struct QueueSnapshot: Sendable {
    var running: GenerationQueueItem?
    var queued: [GenerationQueueItem]
    var completed: [GenerationQueueItem]

    static var empty: QueueSnapshot {
        QueueSnapshot(running: nil, queued: [], completed: [])
    }
}

actor GenerationQueueService {
    typealias Processor = @Sendable (GenerationJob) async -> Result<GenerationResult, Error>

    private var queue: [GenerationQueueItem] = []
    private var running: GenerationQueueItem?
    private var completed: [GenerationQueueItem] = []
    private var processingTask: Task<Void, Never>?
    fileprivate var processorOverride: Processor
    private var continuations: [UUID: AsyncStream<QueueSnapshot>.Continuation] = [:]

    init(processor: @escaping Processor) {
        self.processorOverride = processor
    }

    func replaceProcessor(_ processor: @escaping Processor) {
        self.processorOverride = processor
    }

    func enqueue(_ job: GenerationJob) async -> UUID {
        var queuedJob = job
        queuedJob.status = .queued
        queue.append(GenerationQueueItem(job: queuedJob, status: .queued))
        publishSnapshot()
        startProcessingIfNeeded()
        return queuedJob.id
    }

    func cancel(jobID: UUID) async {
        if let index = queue.firstIndex(where: { $0.id == jobID }) {
            var canceled = queue.remove(at: index)
            canceled.status = .canceled
            completed.insert(canceled, at: 0)
            publishSnapshot()
            return
        }

        if running?.id == jobID {
            processingTask?.cancel()
        }
    }

    func snapshots() -> AsyncStream<QueueSnapshot> {
        let token = UUID()
        return AsyncStream { continuation in
            continuations[token] = continuation
            continuation.yield(snapshot())
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(token: token) }
            }
        }
    }

    func currentSnapshot() async -> QueueSnapshot {
        snapshot()
    }

    private func removeContinuation(token: UUID) {
        continuations.removeValue(forKey: token)
    }

    private func startProcessingIfNeeded() {
        guard processingTask == nil else { return }
        guard !queue.isEmpty else { return }

        processingTask = Task {
            while !Task.isCancelled {
                guard !queue.isEmpty else {
                    running = nil
                    publishSnapshot()
                    break
                }

                var item = queue.removeFirst()
                item.status = .running
                running = item
                publishSnapshot()

                let result = await processorOverride(item.job)

                switch result {
                case let .success(value):
                    item.status = .succeeded
                    item.result = value
                    item.errorMessage = nil
                case let .failure(error):
                    if Task.isCancelled {
                        item.status = .canceled
                        item.errorMessage = "Canceled"
                    } else {
                        item.status = .failed
                        item.errorMessage = error.localizedDescription
                    }
                }

                running = nil
                completed.insert(item, at: 0)
                publishSnapshot()
            }

            processingTask = nil
        }
    }

    private func snapshot() -> QueueSnapshot {
        QueueSnapshot(running: running, queued: queue, completed: completed)
    }

    private func publishSnapshot() {
        let current = snapshot()
        for continuation in continuations.values {
            continuation.yield(current)
        }
    }
}
