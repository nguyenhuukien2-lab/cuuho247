package com.example.roadside.ui.request;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.roadside.data.models.Request;
import com.example.roadside.data.repository.RequestRepository;
import com.example.roadside.utils.Constants;
import com.example.roadside.utils.SharedPrefsHelper;

public class RequestViewModel extends AndroidViewModel {

    private final RequestRepository requestRepository;
    private final SharedPrefsHelper prefsHelper;
    private final MutableLiveData<Long> createdRequestId = new MutableLiveData<>();

    public RequestViewModel(@NonNull Application application) {
        super(application);
        requestRepository = new RequestRepository(application);
        prefsHelper = new SharedPrefsHelper(application);
    }

    public LiveData<Long> getCreatedRequestId() {
        return createdRequestId;
    }

    public void createRequest(String serviceType, String description, String location) {
        int userId = prefsHelper.getUserId();
        Request request = new Request();
        request.setUserId(userId);
        request.setServiceType(serviceType);
        request.setDescription(description);
        request.setLatitude(10.7769);
        request.setLongitude(106.7009);
        request.setStatus(Constants.STATUS_PENDING);
        request.setCreatedAt(String.valueOf(System.currentTimeMillis()));
        request.setCost(300000.0);

        long id = requestRepository.createRequest(request);
        createdRequestId.setValue(id);
    }
}
