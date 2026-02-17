import XCTest
@testable import AuroraStudioApp

actor Probe {
    private var processed: [UUID] = []

    func append(_ id: UUID) {
        processed.append(id)
    }

    func values() -> [UUID] {
        processed
    }
}

final class QueueServiceTests: XCTestCase {
    func testQueueProcessesSingleActiveInOrder() async throws {
        let probe = Probe()

        let queue = GenerationQueueService { job in
            try? await Task.sleep(for: .milliseconds(20))
            await probe.append(job.id)
            let image = GeneratedImage(mimeType: "image/png", base64Data: "aGVsbG8=")
            let result = GenerationResult(
                jobID: job.id,
                modelID: job.modelID,
                generatedAt: .now,
                text: "ok",
                images: [image],
                storedAssets: []
            )
            return .success(result)
        }

        let job1 = GenerationJob(mode: .textToImage, prompt: "one", modelID: "openai/gpt-5-image")
        let job2 = GenerationJob(mode: .textToImage, prompt: "two", modelID: "openai/gpt-5-image")

        _ = await queue.enqueue(job1)
        _ = await queue.enqueue(job2)

        try? await Task.sleep(for: .milliseconds(200))

        let order = await probe.values()
        XCTAssertEqual(order, [job1.id, job2.id])

        let snapshot = await queue.currentSnapshot()
        XCTAssertNil(snapshot.running)
        XCTAssertTrue(snapshot.queued.isEmpty)
        XCTAssertEqual(snapshot.completed.count, 2)
        XCTAssertEqual(snapshot.completed.first?.status, .succeeded)
    }
}
