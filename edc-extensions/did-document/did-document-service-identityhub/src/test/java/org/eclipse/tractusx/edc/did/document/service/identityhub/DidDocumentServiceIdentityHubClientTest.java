/********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ********************************************************************************/

package org.eclipse.tractusx.edc.did.document.service.identityhub;

import java.io.IOException;
import java.util.Base64;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.iam.did.spi.document.Service;
import static org.eclipse.edc.junit.assertions.AbstractResultAssert.assertThat;
import org.eclipse.edc.spi.monitor.Monitor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import okhttp3.Protocol;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;

class DidDocumentServiceIdentityHubClientTest {

    private static final String IDENTITY_API_URL = "http://provider-ih:15151/api/identity";
    private static final String PARTICIPANT_ID = "did:web:provider-ih:provider";
    private static final String OWN_DID = "did:web:provider-ih:provider";
    private static final String API_KEY = "c3VwZXItdXNlcg==.superuserkey";
    private static final String SERVICE_ID = "dsp-endpoint";
    private static final String SERVICE_TYPE = "DataService";
    private static final String SERVICE_ENDPOINT = "http://provider-cp:8084/api/v1/dsp/.well-known/dspace-version";

    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final Monitor monitor = mock(Monitor.class);

    private DidDocumentServiceIdentityHubClient client;

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        when(monitor.withPrefix(anyString())).thenReturn(monitor);
        client = new DidDocumentServiceIdentityHubClient(
                httpClient, IDENTITY_API_URL, PARTICIPANT_ID, OWN_DID, API_KEY, monitor);
    }

    @SuppressWarnings("unchecked")
    @Test
    void update_shouldDeleteThenCreate() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenReturn(response(404))   // delete: not found
                .thenReturn(response(204));   // create: success

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();

        var captor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient, times(2)).execute(captor.capture(), any(List.class));

        var requests = captor.getAllValues();

        // First request: DELETE
        assertThat(requests.get(0).method()).isEqualTo("DELETE");
        assertThat(requests.get(0).url().toString()).contains("/endpoints/" + SERVICE_ID);
        assertThat(requests.get(0).header("x-api-key")).isEqualTo(API_KEY);

        // Second request: POST
        assertThat(requests.get(1).method()).isEqualTo("POST");
        assertThat(requests.get(1).url().toString()).contains("/endpoints?autoPublish=true");
        assertThat(requests.get(1).header("x-api-key")).isEqualTo(API_KEY);
    }

    @SuppressWarnings("unchecked")
    @Test
    void update_shouldEncodeParticipantAndDidInBase64() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenReturn(response(404))
                .thenReturn(response(204));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        client.update(service);

        var captor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient, times(2)).execute(captor.capture(), any(List.class));

        var expectedParticipantB64 = Base64.getEncoder().encodeToString(PARTICIPANT_ID.getBytes());
        var expectedDidB64 = Base64.getEncoder().encodeToString(OWN_DID.getBytes());

        var url = captor.getAllValues().get(1).url().toString();
        assertThat(url).contains("/participants/" + expectedParticipantB64 + "/dids/" + expectedDidB64 + "/endpoints");
    }

    @SuppressWarnings("unchecked")
    @Test
    void update_shouldFailWhenCreateFails() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenReturn(response(404))    // delete: not found (tolerated)
                .thenReturn(response(500));    // create: server error

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
    }

    @SuppressWarnings("unchecked")
    @Test
    void update_shouldSucceedWhenCreateReturns409() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenReturn(response(204))    // delete: success
                .thenReturn(response(409));   // create: conflict (tolerated — idempotent)

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();
    }

    @SuppressWarnings("unchecked")
    @Test
    void deleteById_shouldCallDeleteEndpoint() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenReturn(response(204));

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isSucceeded();

        var captor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient).execute(captor.capture(), any(List.class));

        assertThat(captor.getValue().method()).isEqualTo("DELETE");
        assertThat(captor.getValue().url().toString()).contains("/endpoints/" + SERVICE_ID + "?autoPublish=true");
    }

    @SuppressWarnings("unchecked")
    @Test
    void deleteById_shouldSucceedWhenNotFound() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenReturn(response(404));

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isSucceeded();
    }

    @SuppressWarnings("unchecked")
    @Test
    void update_shouldFailWhenHttpClientThrows() throws IOException {
        when(httpClient.execute(any(Request.class), any(List.class)))
                .thenThrow(new IOException("Connection refused"));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
    }

    private static Response response(int code) {
        return new Response.Builder()
                .request(new Request.Builder().url("http://localhost").build())
                .protocol(Protocol.HTTP_1_1)
                .code(code)
                .message("OK")
                .body(ResponseBody.create("", null))
                .build();
    }
}
