package com.example.roadside.data.models;

import androidx.room.Entity;
import androidx.room.PrimaryKey;

@Entity(tableName = "requests")
public class Request {
    @PrimaryKey(autoGenerate = true)
    private int id;
    private int userId;
    private String serviceType;
    private String description;
    private double latitude;
    private double longitude;
    private String status;
    private String createdAt;
    private int providerId;
    private double cost;

    public Request() {}

    public Request(int id, int userId, String serviceType, String description, double latitude, double longitude, String status, String createdAt, int providerId, double cost) {
        this.id = id;
        this.userId = userId;
        this.serviceType = serviceType;
        this.description = description;
        this.latitude = latitude;
        this.longitude = longitude;
        this.status = status;
        this.createdAt = createdAt;
        this.providerId = providerId;
        this.cost = cost;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getUserId() { return userId; }
    public void setUserId(int userId) { this.userId = userId; }

    public String getServiceType() { return serviceType; }
    public void setServiceType(String serviceType) { this.serviceType = serviceType; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }

    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    public int getProviderId() { return providerId; }
    public void setProviderId(int providerId) { this.providerId = providerId; }

    public double getCost() { return cost; }
    public void setCost(double cost) { this.cost = cost; }
}
