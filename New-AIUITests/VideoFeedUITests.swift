import XCTest

final class VideoFeedUITests: XCTestCase {
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }
    
    func testVideoFeedLoading() throws {
        // Wait for the feed to load (adjust timeout if needed)
        let timeout: TimeInterval = 10
        let startTime = Date()
        
        // Keep checking for videos until timeout
        while Date().timeIntervalSince(startTime) < timeout {
            // Log the page source for debugging
            print("Current UI Hierarchy:")
            print(app.debugDescription)
            
            // Check if any video elements are present using more specific queries
            let videoList = app.scrollViews.firstMatch
            if videoList.exists {
                // Look for video cells or containers
                let videoCells = videoList.cells.count > 0 ? videoList.cells : videoList.otherElements
                if videoCells.count > 0 {
                    XCTAssertTrue(true, "Videos are present in the feed")
                    return
                }
            }
            
            // Wait a bit before checking again
            Thread.sleep(forTimeInterval: 1.0)
        }
        
        XCTFail("No videos appeared in the feed within \(timeout) seconds")
    }
    
    func testVideoFeedInteraction() throws {
        // Wait for initial load
        sleep(5)
        
        // Get the main scroll view
        let mainScrollView = app.scrollViews.firstMatch
        
        // Verify scroll view exists
        XCTAssertTrue(mainScrollView.exists, "Main scroll view should exist")
        
        // Try to swipe up a few times to test video loading
        for i in 0..<3 {
            mainScrollView.swipeUp()
            sleep(2) // Wait for potential loading
            
            // Verify content after swipe
            let videoCells = mainScrollView.cells.count > 0 ? mainScrollView.cells : mainScrollView.otherElements
            XCTAssertTrue(videoCells.count > 0, "Video content should be visible after swipe \(i + 1)")
            
            // Log the current state
            print("UI after swipe \(i + 1):")
            print(app.debugDescription)
        }
        
        // Verify we can swipe back down
        mainScrollView.swipeDown()
        
        // Basic assertion that the app is still responsive
        XCTAssertTrue(app.exists, "App should still be running after interaction")
    }
} 