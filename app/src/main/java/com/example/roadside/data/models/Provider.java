package com.example.roadside.data.models;

public class Provider {
    private int id;
    private String name;
    private String phone;
    private double rating;
    private double latitude;
    private double longitude;
    private String vehicleType;
    private boolean available;
    private double distance;

    public Provider() {}

    public Provider(int id, String name, String phone, double rating, double latitude, double longitude, String vehicleType, boolean available, double distance) {
        this.id = id;
        this.name = name;
        this.phone = phone;
        this.rating = rating;
        this.latitude = latitude;
        this.longitude = longitude;
        this.vehicleType = vehicleType;
        this.available = available;
        this.distance = distance;
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public double getRating() { return rating; }
    public void setRating(double rating) { this.rating = rating; }

    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }

    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }

    public String getVehicleType() { return vehicleType; }
    public void setVehicleType(String vehicleType) { this.vehicleType = vehicleType; }

    public boolean isAvailable() { return available; }
    public void setAvailable(boolean available) { this.available = available; }

    public double getDistance() { return distance; }
    public void setDistance(double distance) { this.distance = distance; }
}
