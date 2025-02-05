this is what the firebase schema should look like:

## 1. Users Collection  
Path: `/users/{userId}`  
Each document here is keyed by the user’s Firebase Auth UID. It holds static profile data (like email, display name, and preferences) and dynamic behavioral data (watch history, likes, and social relationships) that feed downstream analytics and recommendations.

### Document Fields:  
- email, displayName, profilePictureURL, socialProvider, registrationDate, emailVerified  
- interests (array): from onboarding  
- preferences (map): content filters, notification settings, etc.  
- role (string): user, moderator, admin  
- bio, settings, lastLogin  
- failedLoginAttempts, lockUntil: for rate‑limiting and security

### Subcollections:  

- Device Tokens:  
  - Path: `/users/{userId}/deviceTokens/{tokenId}`  
  - Fields: token, platform, lastUpdated  
  - Connectivity: These tokens are used by Cloud Functions to trigger push notifications via Firebase Cloud Messaging (FCM) when events occur in other parts of the system (such as new comments or moderation actions).

- Watch History:  
  - Path: `/users/{userId}/watchHistory/{historyId}`  
  - Fields: videoID, watchedAt, duration, completionPercentage, rewatchCount  
  - Connectivity: This data is fed into the ML pipeline via Cloud Functions (published through Pub/Sub) to aggregate viewing behavior. It directly informs the Recommendations collection by helping to compute the user’s behavioral vector.

- Liked Videos:  
  - Path: `/users/{userId}/likedVideos/{likeId}`  
  - Fields: videoID, likedAt  
  - Connectivity: These likes are cross‑referenced with video documents and are used both to update per‑video like counts (via transactions/Cloud Functions) and to help refine personalized recommendations.

- Saved Videos (Bookmarks):  
  - Path: `/users/{userId}/savedVideos/{savedId}`  
  - Fields: videoID, savedAt

- Chat Sessions:  
  - Path: `/users/{userId}/chatSessions/{sessionId}`  
  - Fields: startedAt, endedAt  
  - Nested Messages:  
    - Path: `/users/{userId}/chatSessions/{sessionId}/messages/{messageId}`  
    - Fields: sender, text, timestamp, rating  
  - Connectivity: These chat records (whether for conversational AI assistance or direct messaging) link to user profiles and can be used for sentiment analysis and further personalization.

- Notifications:  
  - Path: `/users/{userId}/notifications/{notificationId}`  
  - Fields: type, message, referenceID, timestamp, read  
  - Connectivity: Cloud Functions update notifications in real‑time when key events occur (for example, when a video finishes processing or a comment is posted).

- Social Relations (Followers/Following):  
  - Subcollections: `/users/{userId}/followers/` and `/users/{userId}/following/`  
  - Fields: followerID/followingID, followedAt  
  - Connectivity: These relationships not only drive the social feed but also feed into the look alike clustering algorithm, as users with similar follow patterns are grouped for recommendations.

---

## 2. Videos Collection  
Path: `/videos/{videoId}`  
Each document represents an uploaded video, storing technical metadata and comprehensive engagement metrics.

### Document Fields:  
- uploaderID: Reference to a user in `/users`.
- title, description, tags, status (processing, processed, error)
- videoURL, thumbnailURL, uploadDate  
- duration, resolution, fileSize  
- viewCount, likeCount, commentCount  
- totalWatchTime, averageWatchTime, completionRate, rewatchRate  
- transcript, summary: (AI‑generated content)  
- engagementScore: Composite metric from interactions  
- processingMetadata: Contains transcodingStatus, thumbnailStatus, transcriptStatus, summaryStatus  
- searchKeywords: For aiding external search engines

### Subcollections:  

- Comments:  
  - Path: `/videos/{videoId}/comments/{commentId}`  
  - Fields: userID, text, timestamp, likeCount, edited, editTimestamp  
  - Nested Comment Likes (optional):  
    - Path: `/videos/{videoId}/comments/{commentId}/likes/{likeId}`  
    - Fields: userID, likedAt  
  - Connectivity: Comment interactions update the video's engagement score in real time via Cloud Functions and contribute to user sentiment analysis.

- Likes: (Alternate detailed tracking)  
  - Path: `/videos/{videoId}/likes/{likeId}`  
  - Fields: userID, likedAt

---

## 3. Engagement Events Collection  
Path: `/engagementEvents/{eventId}`  
Every discrete user interaction (views, likes, comments, shares, skips, rewatch events) is logged here to serve as raw input for analytics and machine learning.

### Fields:  
- userID, videoID, eventType, eventTimestamp  
- sessionID: To group interactions by a viewing session  
- deviceInfo (map): e.g., device type, OS, app version  
- geolocation (geopoint, optional)  
- metadata (map): Additional context

Connectivity:  
Each event is published to a Cloud Pub/Sub topic. Cloud Functions subscribe to these events to update aggregated counters (in the Aggregated Counters collection) and trigger recalculation of recommendations.

---

## 4. Recommendations Collection  
Path: `/recommendations/{userId}`  
Stores personalized recommendations computed from aggregated engagement data, user watch history, and look alike audience clustering.

### Fields:  
- lastUpdated (timestamp)  
- videos (array of maps): Each map includes:  
  - videoID, rationale (e.g., “Because you watched [Video Title]…”)
- algorithmVersion (string)  
- userProfileVector (array/map, optional): A behavioral vector derived from watch history and engagement events  
- engagementData (map, optional): Summary metrics (average watch time, completion rate, etc.)

Connectivity:  
Cloud Functions use data from the Engagement Events and Aggregated Counters collections, as well as the social graph, to compute recommendations and write updates here. This collection feeds directly into the feed UI.

---

## 5. Guides Collection  
Path: `/guides/{guideId}`  
Holds AI-generated guides (e.g., Sleep Guide, Habit Tracker) available for download.

### Fields:  
- userID (optional): For personalized guides  
- guideType (string)  
- contentPDFUrl (string): Link to the PDF in Cloud Storage  
- generatedAt (timestamp)  
- customizationOptions (array of strings, optional)  
- rating (number, optional)

Connectivity:  
Guide requests trigger Cloud Functions that analyze video transcripts and metadata, generate guides, and store them here. The guide generation process can also feed back user ratings to improve AI quality.

---

## 6. Tasks Collection  
Path: `/tasks/{taskId}`  
Represents actionable items extracted from video content that can be integrated with external calendars/task managers.

### Fields:  
- videoID (string)  
- userID (string) – The user assigned the task  
- taskDescription (string)  
- createdAt (timestamp)  
- status (string): e.g., "pending", "completed", "dismissed"  
- dueDate (timestamp, optional)  
- calendarIntegration (map, optional): Contains externalTaskID, integrationStatus

Connectivity:  
Tasks are generated based on NLP extraction from video transcripts (triggered by Cloud Functions) and are then synchronized with external services via API integrations.

---

## 7. Processing Logs Collection  
Path: `/processingLogs/{logId}`  
(Optional) Captures asynchronous processing events (transcoding, thumbnail generation, transcript creation) for troubleshooting and performance monitoring.

### Fields:  
- videoID (string)  
- event (string) – e.g., "transcoding_started", "thumbnail_generated"  
- timestamp (timestamp)  
- details (map or string, optional)

Connectivity:  
Cloud Functions write logs here as videos move through processing pipelines. These logs are used for debugging and triggering subsequent actions (e.g., updating video status).

---

## 8. Global App Settings Collection  
Path: `/appSettings/{settingId}`  
Holds app‑wide configuration data and feature flags.

### Fields:  
- name (string)  
- value (boolean/number/string)  
- updatedAt (timestamp)

Connectivity:  
Client apps query this collection at startup (and periodically via snapshot listeners) to adjust feature availability and UI settings. Cloud Functions may update these settings in response to administrative changes.

---

## 9. Audit Logs Collection  
Path: `/auditLogs/{logId}`  
Captures critical user actions and administrative events for security and compliance.

### Fields:  
- userID (string)  
- action (string) – e.g., "profile_update", "login", "moderation_action"  
- timestamp (timestamp)  
- metadata (map): e.g., IP address, device info

Connectivity:  
Audit logs are written by Cloud Functions triggered by sensitive operations. They feed into security dashboards and external monitoring systems.

---

## 10. Aggregated Counters / Analytics Collection  
Path: `/aggregatedCounters/{counterId}`  
Stores summary statistics (e.g., daily views, total users) used for reporting and as inputs to the recommendation engine.

### Fields:  
- metricName (string) – e.g., "dailyViews", "totalUsers"  
- value (number)  
- timestamp (timestamp)

Connectivity:  
Cloud Functions subscribe to the Pub/Sub topic from the Engagement Events collection to update these counters. They provide a fast lookup for dashboards and ML pipelines.

---

## 11. Social Graph Collection  
Path: `/userRelations/{relationId}`  
(If not using subcollections in Users) This standalone collection records follow relationships for social connectivity and look alike audience analysis.

### Fields:  
- userID (string) – The user being followed  
- followerID (string) – The follower’s UID  
- followedAt (timestamp)  
- relationType (string) – Typically "follower"

Connectivity:  
Social graph data is used by the recommendation algorithm to identify similar users and to drive social feed logic. Cloud Functions update this collection when follow/unfollow events occur.











graph TD
  %% USERS BLOCK
  subgraph "Users Module"
    U[Users Collection<br/>(/users/{userId})]
    U1[Device Tokens<br/>(/users/{userId}/deviceTokens)]
    U2[Watch History<br/>(/users/{userId}/watchHistory)]
    U3[Liked Videos<br/>(/users/{userId}/likedVideos)]
    U4[Saved Videos<br/>(/users/{userId}/savedVideos)]
    U5[Chat Sessions<br/>(/users/{userId}/chatSessions)]
    U5a[Messages<br/>(nested in Chat Sessions)]
    U6[Notifications<br/>(/users/{userId}/notifications)]
    U7[Social Relations<br/>(Followers/Following)]
  end

  %% VIDEOS BLOCK
  subgraph "Videos Module"
    V[Videos Collection<br/>(/videos/{videoId})]
    V1[Comments<br/>(/videos/{videoId}/comments)]
    V1a[Comment Likes<br/>(nested in Comments)]
    V2[Likes<br/>(/videos/{videoId}/likes)]
  end

  %% ENGAGEMENT EVENTS
  subgraph "Engagement & Analytics"
    EE[Engagement Events<br/>(/engagementEvents)]
    AC[Aggregated Counters<br/>(/aggregatedCounters)]
  end

  %% RECOMMENDATIONS
  subgraph "Recommendations & ML"
    R[Recommendations<br/>(/recommendations/{userId})]
  end

  %% GUIDES & TASKS
  subgraph "Guides & Tasks"
    G[Guides<br/>(/guides)]
    T[Tasks<br/>(/tasks)]
  end

  %% LOGS & SETTINGS
  subgraph "Admin & Config"
    PL[Processing Logs<br/>(/processingLogs)]
    AS[Global App Settings<br/>(/appSettings)]
    AL[Audit Logs<br/>(/auditLogs)]
  end

  %% SOCIAL GRAPH (OPTIONAL)
  SG[Social Graph<br/>(/userRelations)]

  %% CONNECTIVE INFRASTRUCTURE
  subgraph "Connective Components"
    EB[Event Bus / PubSub]
    ES[External Search Index]
    ML[ML Pipeline Integration]
    CF[Cloud Functions]
    ML2[Monitoring & Logging]
  end

  %% USERS CONNECTIONS
  U --> U1
  U --> U2
  U --> U3
  U --> U4
  U --> U5
  U5 --> U5a
  U --> U6
  U --> U7

  %% VIDEOS CONNECTIONS
  V --> V1
  V1 --> V1a
  V --> V2

  %% ENGAGEMENT EVENTS and their Connectors
  EE --> U
  EE --> V
  EE --> EB

  %% Cloud Functions and External Connectors
  EB --> CF
  CF --> AC
  CF --> R
  CF --> ES
  CF --> ML
  CF --> ML2

  %% ML Pipeline uses Aggregated Counters to update Recommendations
  AC --> ML
  ML --> R

  %% Admin/Config Connections
  U -- "Reads App Settings" --> AS
  U -- "Action Logs" --> AL
  V -- "Processing Events" --> PL
  U7 --- SG

  %% Guides and Tasks are associated with Videos
  G --- V
  T --- V

  %% Real-time & Client-side Connectors (implicit)
  CF --- EB
  CF --- ML2
