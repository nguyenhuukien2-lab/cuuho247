package com.example.roadside.ui.providers;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModel;

import com.example.roadside.data.models.Provider;
import com.example.roadside.data.repository.ProviderRepository;

import java.util.List;

public class ProvidersViewModel extends ViewModel {

    private final ProviderRepository providerRepository;
    private final MutableLiveData<List<Provider>> providerList = new MutableLiveData<>();

    public ProvidersViewModel() {
        providerRepository = new ProviderRepository();
        loadProviders();
    }

    public LiveData<List<Provider>> getProviderList() {
        return providerList;
    }

    public void loadProviders() {
        List<Provider> providers = providerRepository.getMockProviders();
        providerList.setValue(providers);
    }
}
