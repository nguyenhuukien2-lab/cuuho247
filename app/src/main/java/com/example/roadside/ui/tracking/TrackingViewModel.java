package com.example.roadside.ui.tracking;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.roadside.data.models.Request;
import com.example.roadside.data.repository.RequestRepository;
import com.example.roadside.utils.Constants;

public class TrackingViewModel extends AndroidViewModel {

    private final RequestRepository requestRepository;
    private final MutableLiveData<Request> currentRequest = new MutableLiveData<>();

    public TrackingViewModel(@NonNull Application application) {
        super(application);
        requestRepository = new RequestRepository(application);
    }

    public LiveData<Request> getCurrentRequest() {
        return currentRequest;
    }

    public void loadRequest(int requestId) {
        Request request = requestRepository.getRequestById(requestId);
        if (request == null) {
            request = new Request();
            request.setId(requestId);
            request.setServiceType("Cứu Hộ Ô Tô");
            request.setStatus(Constants.STATUS_IN_PROGRESS);
            request.setCost(500000);
        }
        currentRequest.setValue(request);
    }
}
