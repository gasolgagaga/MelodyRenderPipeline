﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class ScreenSpaceAmbientOcclusion {
    const string bufferName = "ScreenSpaceAmbientOcclusion";
    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };
    ScriptableRenderContext context;
    Camera camera;
    CameraBufferSettings.SSAO settings;
    Vector2Int bufferSize;
    ComputeShader cs;

    Texture2D randomVectors;
    int ssaoResultId = Shader.PropertyToID("AmbientOcclusionRT");

    public void Setup(ScriptableRenderContext context, Camera camera, Vector2Int bufferSize, CameraBufferSettings.SSAO settings) {
        this.context = context;
        this.camera = camera;
        this.bufferSize = bufferSize;
        this.settings = settings;
        this.cs = settings.computeShader;
    }

    void Configure() {
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(bufferSize.x, bufferSize.y, RenderTextureFormat.Default, 0, 0);
        descriptor.sRGB = false;
        descriptor.enableRandomWrite = true;
        buffer.GetTemporaryRT(ssaoResultId, descriptor);

        InitRandomVectors();
    }

    public void Render(int sourceId) {
        buffer.BeginSample("SSAO Resolve");
        //divide by shader's numthreads.x
        int dispatchThreadGroupXCount = bufferSize.x / 8;
        //divide by shader's numthreads.y
        int dispatchThreadGroupYCount = bufferSize.y / 8;
        //divide by shader's numthreads.z
        int dispatchThreadGroupZCount = 1;
        if (settings.enabled) {
            Configure();
            buffer.SetComputeIntParam(cs, "sampleCount", settings.sampleCount);
            buffer.SetComputeFloatParam(cs, "radius", settings.radius);
            buffer.SetComputeFloatParam(cs, "bias", settings.bias);
            buffer.SetComputeFloatParam(cs, "magnitude", settings.magnitude);
            buffer.SetComputeFloatParam(cs, "constrast", settings.constrast);
            Matrix4x4 projection = camera.projectionMatrix;
            buffer.SetComputeMatrixParam(cs, "_CameraProjection", projection);
            buffer.SetComputeMatrixParam(cs, "_CameraInverseProjection", projection.inverse);
            int kernel_SSAOResolve = cs.FindKernel("SSAOResolve");
            buffer.SetComputeTextureParam(cs, kernel_SSAOResolve, "_RandomVectors", randomVectors);
            buffer.SetComputeTextureParam(cs, kernel_SSAOResolve, "AmbientOcclusionRT", ssaoResultId);
            buffer.DispatchCompute(cs, kernel_SSAOResolve, dispatchThreadGroupXCount, dispatchThreadGroupYCount, dispatchThreadGroupZCount);

            buffer.Blit(ssaoResultId, sourceId);
        }
        buffer.EndSample("SSAO Resolve");
        ExecuteBuffer();
    }

    public void CleanUp() {
        buffer.ReleaseTemporaryRT(ssaoResultId);
        ExecuteBuffer();
    }

    void InitRandomVectors() {
        if (randomVectors == null) {
            int textureSize = settings.sampleCount;
            randomVectors = new Texture2D(textureSize, 1, TextureFormat.RGBAHalf, false, true);
            randomVectors.name = "Random Vectors";
            Color[] colors = new Color[textureSize];
            for (int i = 0; i < colors.Length; i++) {
                Vector3 vector = Random.insideUnitSphere;
                colors[i] = new Color(vector.x, vector.y, vector.z, 1);
            }
            randomVectors.SetPixels(colors);
            randomVectors.Apply();
        }
    }

    void ExecuteBuffer() {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
