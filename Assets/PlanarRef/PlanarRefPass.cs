using System.Collections.Generic;
using UnityEditor;
using UnityEditor.ShaderGraph.Internal;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.XR;
using UnityTemplateProjects;

namespace PlanarRef
{
    public class PlanarRefPass : ScriptableRenderPass
    {
        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();

        FilteringSettings m_FilteringSettings;
        ProfilingSampler m_ProfilingSampler;

        private ScriptableRenderer m_Renderer;
        private RenderTextureDescriptor m_MirrorDescriptor;
        private Material m_Material;

        private RTHandle m_MirrorTexture;
        private static readonly int s_MirrorTextureID = Shader.PropertyToID("_MirrorTex");

        private PlanarRefFeature m_feature;

        public bool Setup(ScriptableRenderer renderer, Material material, PlanarRefFeature feature)
        {
            m_Material = material;
            m_Renderer = renderer;
            m_feature = feature;
            return true;
        }

        public PlanarRefPass(LayerMask layerMask)
        {
            m_ProfilingSampler = new ProfilingSampler("PlanarRef");

            m_ShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
            m_ShaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));


            m_FilteringSettings = new FilteringSettings(RenderQueueRange.opaque, layerMask);

            m_MirrorTexture = RTHandles.Alloc(new RenderTargetIdentifier(s_MirrorTextureID), "_MirrorTex");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var cameraData = renderingData.cameraData;
            
            var cameraTargetDescriptor = cameraData.cameraTargetDescriptor;
            RenderTextureDescriptor descriptor = cameraTargetDescriptor;
            m_MirrorDescriptor = descriptor;

            if (cameraData.camera.name.Contains("SceneCamera"))
            {
                m_MirrorDescriptor.width = SceneView.lastActiveSceneView.camera.pixelWidth;
                m_MirrorDescriptor.height = SceneView.lastActiveSceneView.camera.pixelHeight;
            }

            cmd.GetTemporaryRT(s_MirrorTextureID, m_MirrorDescriptor, FilterMode.Bilinear);
        }

        private Matrix4x4 CalculateObliqueMatrix(Vector4 worldSpacePlane, Matrix4x4 viewMatrix, Matrix4x4 projectionMatrix)
        {
            var viewSpacePlane = viewMatrix.inverse.transpose * worldSpacePlane;
            var clipSpaceFarPanelBoundPoint = new Vector4(Mathf.Sign(viewSpacePlane.x), Mathf.Sign(viewSpacePlane.y), 1, 1);
            var viewSpaceFarPanelBoundPoint = projectionMatrix.inverse * clipSpaceFarPanelBoundPoint;
        
            var m4 = new Vector4(projectionMatrix.m30, projectionMatrix.m31, projectionMatrix.m32, projectionMatrix.m33);
            //u = 2 * (M4·E)/(E·P)，而M4·E == 1，化简得
            //var u = 2.0f * Vector4.Dot(m4, viewSpaceFarPanelBoundPoint) / Vector4.Dot(viewSpaceFarPanelBoundPoint, viewSpacePlane);
            var u = 2.0f / Vector4.Dot(viewSpaceFarPanelBoundPoint, viewSpacePlane);
            var newViewSpaceNearPlane = u * viewSpacePlane;
 
            //M3' = P - M4
            var m3 = newViewSpaceNearPlane - m4;
 
            projectionMatrix.m20 = m3.x;
            projectionMatrix.m21 = m3.y;
            projectionMatrix.m22 = m3.z;
            projectionMatrix.m23 = m3.w;
 
            return projectionMatrix;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // if (!renderingData.cameraData.camera.name.Contains("mirror"))
            // {
            //     return;
            // }
            var sortingCriteria = renderingData.cameraData.defaultOpaqueSortFlags;
            var drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);

            ref var cameraData = ref renderingData.cameraData;
            var camera = cameraData.camera;

            var cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                CoreUtils.SetRenderTarget(cmd, m_MirrorTexture, ClearFlag.All, Color.clear);

                var isSceneCamera = camera.name.Contains("SceneCamera");

                var camTransform = camera.transform;
                var rotation = camTransform.rotation;

                CullingResults cullingResults;
                var mirrorPos = MirrorPlanar.mirrorPos(MirrorPlanar.Plane,camTransform.position);
                var viewM = MirrorPlanar.GetViewMat(camTransform.position, rotation);

                var projectionMatrix = camera.projectionMatrix;

                var planeTr = MirrorPlanar.Plane;
                var normal = planeTr.forward;
                var d = -Vector3.Dot(normal, planeTr.position);
                var plane = new Vector4(normal.x, normal.y, normal.z, d);
                projectionMatrix = CalculateObliqueMatrix(plane,viewM,projectionMatrix);
                projectionMatrix[8] *= -1;

                var cullMat = Matrix4x4.Frustum(-1, 1, -1, 1, 0.0000001f, 10000000f);

                camera.cullingMatrix = cullMat * viewM;
                camera.TryGetCullingParameters(out var cullingParameters);
                cullingResults = context.Cull(ref cullingParameters);

                projectionMatrix = GL.GetGPUProjectionMatrix(projectionMatrix, cameraData.IsCameraProjectionMatrixFlipped());

                if (cameraData.xrRendering)
                {
                    var leftEyePos = camera.GetStereoViewMatrix(Camera.StereoscopicEye.Left).inverse.GetColumn(3);
                    var rightEyePos = camera.GetStereoViewMatrix(Camera.StereoscopicEye.Right).inverse.GetColumn(3);

                    Vector4 leftMirrorPos = MirrorPlanar.mirrorPos(MirrorPlanar.Plane,leftEyePos);
                    Vector4 rightMirrorPos = MirrorPlanar.mirrorPos(MirrorPlanar.Plane,rightEyePos);

                    var leftViewM = MirrorPlanar.GetViewMat(leftEyePos, rotation);
                    var rightViewM = MirrorPlanar.GetViewMat(rightEyePos, rotation);

                    var leftPMat = camera.GetStereoProjectionMatrix(Camera.StereoscopicEye.Left);
                    var rightPMat = camera.GetStereoProjectionMatrix(Camera.StereoscopicEye.Right);

                    leftPMat = CalculateObliqueMatrix(plane,leftViewM,leftPMat);
                    rightPMat = CalculateObliqueMatrix(plane,rightViewM,rightPMat);

                    leftPMat[8] *= -1;
                    rightPMat[8] *= -1;
                    leftPMat = GL.GetGPUProjectionMatrix(leftPMat, cameraData.IsCameraProjectionMatrixFlipped());
                    rightPMat = GL.GetGPUProjectionMatrix(rightPMat, cameraData.IsCameraProjectionMatrixFlipped());

                    cmd.SetGlobalVectorArray(unity_StereoWorldSpaceCameraPos,new []{leftMirrorPos,rightMirrorPos});
                    SetViewAndProjectionMatricesInVR(cmd, new[] { leftViewM, rightViewM },
                        new[] { leftPMat, rightPMat });
                }
                else
                {
                    cmd.SetGlobalVector(worldSpaceCameraPos,new Vector4(mirrorPos.x,mirrorPos.y,mirrorPos.z,0));
                    RenderingUtils.SetViewAndProjectionMatrices(cmd, viewM, projectionMatrix, false);
                }

                context.ExecuteCommandBuffer(cmd);

                cmd.Clear();

                context.DrawRenderers(cullingResults, ref drawingSettings, ref m_FilteringSettings);
                if(m_feature.drawSkybox)
                    context.DrawSkybox(cameraData.camera);

                cmd.SetGlobalTexture(s_MirrorTextureID, m_MirrorTexture.nameID);
                var viewMatrix = camera.worldToCameraMatrix;
                RenderingUtils.SetViewAndProjectionMatrices(cmd, viewMatrix, cameraData.GetGPUProjectionMatrix(), false);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            camera.ResetCullingMatrix();
        }

        public static readonly int StereoViewMatrix = Shader.PropertyToID("unity_StereoMatrixV");
        public static readonly int StereoViewAndProjectionMatrix = Shader.PropertyToID("unity_StereoMatrixVP");
        public static readonly int worldSpaceCameraPos = Shader.PropertyToID("_WorldSpaceCameraPos");
        public static readonly int unity_StereoWorldSpaceCameraPos = Shader.PropertyToID("unity_StereoWorldSpaceCameraPos");

        public static void SetViewAndProjectionMatricesInVR(CommandBuffer cmd, Matrix4x4[] viewMatrix, Matrix4x4[] projectionMatrix)
        {
            var viewAndProjectionMatrix = new[]
            {
                projectionMatrix[0] * viewMatrix[0],
                projectionMatrix[1] * viewMatrix[1]
            };
            cmd.SetGlobalMatrixArray(StereoViewMatrix, viewMatrix);
            cmd.SetGlobalMatrixArray(StereoViewAndProjectionMatrix, viewAndProjectionMatrix);
        }


        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }

        public void Dispose()
        {
            m_MirrorTexture.Release();
        }
    }
}