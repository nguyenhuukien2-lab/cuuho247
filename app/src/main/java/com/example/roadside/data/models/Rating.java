package com.example.roadside.data.models;

public class Rating {
    private int id;
    private int requestId;
    private int providerId;
    private int userId;
    private float ratingValue;
    private String reviewComment;
    private String timestamp;

    public Rating() {}

    public Rating(int id, int requestId, int providerId, int userId, float ratingValue, String reviewComment, String timestamp) {
        this.id = id;
        this.requestId = requestId;
        this.providerId = providerId;
        this.userId = userId;
        this.ratingValue = ratingValue;
        this.reviewComment = reviewComment;
        this.timestamp = timestamp;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getRequestId() { return requestId; }
    public void setRequestId(int requestId) { this.requestId = requestId; }

    public int getProviderId() { return providerId; }
    public void setProviderId(int providerId) { this.providerId = providerId; }

    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }

    public float getRatingValue() { return ratingValue; }
    public void setRatingValue(float ratingValue) { this.ratingValue = ratingValue; }

    public String getReviewComment() { return reviewComment; }
    public void setReviewComment(String reviewComment) { this.reviewComment = reviewComment; }

    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
}
