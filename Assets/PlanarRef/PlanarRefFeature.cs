using System.Collections.Generic;
using PlanarRef;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityTemplateProjects;

namespace PlanarRef
{
    public class PlanarRefFeature : ScriptableRendererFeature
    {
        List<PlanarRefPass> m_ScriptablePassList = new List<PlanarRefPass>();

        public bool drawSkybox;
        public LayerMask LayerMask = ~0;
        private Material m_Material;

        /// <inheritdoc/>
        public override void Create()
        {
            m_ScriptablePassList = new List<PlanarRefPass>();
            var mirrorPlanars = MirrorPlanarCommon.Instance.GetData();
            Debug.Log($"created {mirrorPlanars.Count}" );
            foreach (var mirrorPlanar in mirrorPlanars)
            {
                Debug.Log($"create pass: {mirrorPlanar.renderTexture}");
                 var planarRefPass = new PlanarRefPass(LayerMask,mirrorPlanar);
                 planarRefPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
                m_ScriptablePassList.Add(planarRefPass);
            }
        }

        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera.
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            Debug.Log("AddRenderPasses");
            foreach (var planarRefPass in m_ScriptablePassList)
            {
                planarRefPass.Setup(renderer, m_Material, this);
                renderer.EnqueuePass(planarRefPass);
            }
        }

        protected override void Dispose(bool disposing)
        {
            // foreach (var planarRefPass in m_ScriptablePassList)
            // {
            //     planarRefPass?.Dispose();
            //
            // }
            m_ScriptablePassList.Clear();
            CoreUtils.Destroy(m_Material);
        }
    }
}