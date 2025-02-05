import XCTest

final class VideoFeedUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
        
        // Add a reasonable wait for the app to settle after launch
        sleep(2)
    }
    
    func testVideoFeedLoading() throws {
        // Wait for the feed to load (adjust timeout if needed)
        let timeout: TimeInterval = 15 // Increased timeout for slower networks
        let startTime = Date()
        
        // Keep checking for videos until timeout
        while Date().timeIntervalSince(startTime) < timeout {
            // Log the page source for debugging
            print("Current UI Hierarchy:")
            print(app.debugDescription)
            
            // Check if any video elements are present using more specific queries
            let videoList = app.scrollViews.firstMatch
            if videoList.waitForExistence(timeout: 2) {
                // Look for video cells or containers
                let videoCells = videoList.cells.count > 0 ? videoList.cells : videoList.otherElements
                if videoCells.count > 0 {
                    // Additional verification that cells are actually visible
                    let firstCell = videoCells.firstMatch
                    if firstCell.waitForExistence(timeout: 2) {
                        XCTAssertTrue(true, "Videos are present and visible in the feed")
                        return
                    }
                }
            }
            
            // Wait a bit before checking again
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        XCTFail("No videos appeared in the feed within \(timeout) seconds")
    }
    
    func testVideoFeedInteraction() throws {
        // Wait for initial load with better verification
        let videoList = app.scrollViews.firstMatch
        XCTAssertTrue(videoList.waitForExistence(timeout: 10), "Video list should appear")
        
        // Additional wait for content to load
        sleep(3)
        
        // Verify initial content
        let initialCells = videoList.cells.count > 0 ? videoList.cells : videoList.otherElements
        XCTAssertTrue(initialCells.count > 0, "Initial video content should be visible")
        
        // Try to swipe up a few times to test video loading
        for i in 0..<3 {
            // Log before swipe
            print("Before swipe \(i + 1):")
            print(app.debugDescription)
            
            // Perform swipe
            videoList.swipeUp()
            
            // Wait for loading and verify content after swipe
            sleep(3)
            
            // Verify content after swipe
            let videoCells = videoList.cells.count > 0 ? videoList.cells : videoList.otherElements
            XCTAssertTrue(videoCells.count > 0, "Video content should be visible after swipe \(i + 1)")
            
            // Log the current state
            print("UI after swipe \(i + 1):")
            print(app.debugDescription)
            
            // Additional verification that we can interact with content
            let firstVisibleCell = videoCells.firstMatch
            XCTAssertTrue(firstVisibleCell.exists, "Should have at least one visible video cell after swipe \(i + 1)")
        }
        
        // Verify we can swipe back down
        videoList.swipeDown()
        sleep(1)
        
        // Verify the app is still responsive and showing content
        let finalCells = videoList.cells.count > 0 ? videoList.cells : videoList.otherElements
        XCTAssertTrue(finalCells.count > 0, "Video content should still be visible after interaction")
        XCTAssertTrue(app.exists, "App should still be running after interaction")
    }
} 