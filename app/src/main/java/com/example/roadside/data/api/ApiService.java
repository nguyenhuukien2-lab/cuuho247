package com.example.roadside.data.api;

import com.example.roadside.data.models.Payment;
import com.example.roadside.data.models.Provider;
import com.example.roadside.data.models.Request;
import com.example.roadside.data.models.User;

import java.util.List;

import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.GET;
import retrofit2.http.POST;
import retrofit2.http.Path;

public interface ApiService {

    @POST("auth/login")
    Call<User> login(@Body User user);

    @POST("auth/register")
    Call<User> register(@Body User user);

    @GET("requests/user/{userId}")
    Call<List<Request>> getUserRequests(@Path("userId") int userId);

    @POST("requests")
    Call<Request> createRequest(@Body Request request);

    @GET("providers/nearby")
    Call<List<Provider>> getNearbyProviders();

    @POST("payment/process")
    Call<Payment> processPayment(@Body Payment payment);
}
