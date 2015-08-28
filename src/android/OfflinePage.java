package com.manifoldjs.offlinepage;

import android.content.Intent;
import android.net.Uri;
import android.content.res.AssetManager;
import android.os.Build;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.LinearLayout;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaActivity;
import org.apache.cordova.CordovaPlugin;

import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;

public class OfflinePage extends CordovaPlugin {
    private static final String LOG_TAG = "OfflinePage";
    private static final String OFFLINE_PAGE = "offline.html";
    private static final String OFFLINE_PAGE_TEMPLATE = "<html><body><div style=\"top:50%%;text-align:center;position:absolute\">%s</div></body></html>";

    private CordovaActivity activity;
    private CordovaPlugin whiteListPlugin;

    private LinearLayout rootLayout;
    private WebView offlineWebView;
    private boolean offlineOverlayEnabled;

    private boolean isConnectionError = false;

    @Override
    public void pluginInitialize() {
        final OfflinePage me = OfflinePage.this;
        this.activity = (CordovaActivity)this.cordova.getActivity();

        // Initialize offline overlay
        this.activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (me.rootLayout == null) {
                    me.rootLayout = me.createOfflineRootLayout();
                    me.activity.addContentView(me.rootLayout, me.rootLayout.getLayoutParams());
                }

                if (me.offlineWebView == null) {
                    me.offlineWebView = me.createOfflineWebView();
                    me.rootLayout.addView(me.offlineWebView);
                }

                if (me.assetExists(OfflinePage.OFFLINE_PAGE)) {
                    me.offlineWebView.loadUrl("file:///android_asset/www/" + OfflinePage.OFFLINE_PAGE);
                } else {
                    me.offlineWebView.loadData(
                            String.format(OfflinePage.OFFLINE_PAGE_TEMPLATE, "It looks like you are offline. Please reconnect to use this application."),
                            "text/html",
                            null);
                }

                me.offlineOverlayEnabled = true;
            }
        });
    }

    @Override
    public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
        final OfflinePage me = OfflinePage.this;

        if (action.equals("enableOfflinePage")) {
            this.offlineOverlayEnabled = true;
            return true;
        }

        if (action.equals("disableOfflinePage")) {
            this.offlineOverlayEnabled = false;
            return true;
        }

        return false;
    }

    @Override
    public Object onMessage(String id, Object data) {
        if (id.equals("networkconnection") && data != null) {
            this.handleNetworkConnectionChange(data.toString());
        } else if (id.equals("onPageStarted")) {
            this.isConnectionError = false;
        } else if (id.equals("onReceivedError")) {
            if (data instanceof JSONObject) {
                JSONObject errorData = (JSONObject) data;
                try {
                    int errorCode = errorData.getInt("errorCode");
                    if (404 == errorCode
                            || WebViewClient.ERROR_HOST_LOOKUP == errorCode
                            || WebViewClient.ERROR_CONNECT == errorCode
                            || WebViewClient.ERROR_TIMEOUT == errorCode) {
                        this.isConnectionError = true;
                        this.showOfflineOverlay();
                    }
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }
        }
        else if (id.equals("onPageFinished")) {
            if (!this.isConnectionError) {
                this.hideOfflineOverlay();
            }
        }
        return null;
    }

    private boolean assetExists(String asset) {
        final AssetManager assetManager = this.activity.getResources().getAssets();
        try {
            return Arrays.asList(assetManager.list("www")).contains(asset);
        } catch (IOException e) {
            e.printStackTrace();
        }

        return false;
    }

    private WebView createOfflineWebView() {
        WebView webView = new WebView(activity);
        webView.getSettings().setJavaScriptEnabled(true);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.HONEYCOMB) {
            webView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        }

        webView.setLayoutParams(new LinearLayout.LayoutParams(
                                                 ViewGroup.LayoutParams.MATCH_PARENT,
                                                 ViewGroup.LayoutParams.MATCH_PARENT,
                                                 1.0F));
        return webView;
    }

    private LinearLayout createOfflineRootLayout() {
        LinearLayout root = new LinearLayout(activity.getBaseContext());
        root.setOrientation(LinearLayout.VERTICAL);
        root.setVisibility(View.INVISIBLE);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                                              ViewGroup.LayoutParams.MATCH_PARENT,
                                              ViewGroup.LayoutParams.MATCH_PARENT,
                                              0.0F));
        return root;
    }

    private void handleNetworkConnectionChange(String info) {
        final OfflinePage me = OfflinePage.this;
        if (info.equals("none")) {
            this.showOfflineOverlay();
        } else {
            if (this.isConnectionError) {

                this.activity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        String currentUrl = me.webView.getUrl();
                        me.webView.loadUrlIntoView(currentUrl, false);
                    }
                });
            } else {
                this.hideOfflineOverlay();
            }
        }
    }

    private void showOfflineOverlay() {
        final OfflinePage me = OfflinePage.this;
        if (this.offlineOverlayEnabled) {
            this.activity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    if (me.rootLayout != null) {
                        me.rootLayout.setVisibility(View.VISIBLE);
                }
            }
        });
    }
    }

    private void hideOfflineOverlay() {
        final OfflinePage me = OfflinePage.this;
        this.activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (me.rootLayout != null) {
                    me.rootLayout.setVisibility(View.INVISIBLE);
                }
            }
        });
    }
}
