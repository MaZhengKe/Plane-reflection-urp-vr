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
        private PlanarRefPass planarRefPass;

        public bool drawSkybox;
        public LayerMask LayerMask = ~0;
        private Material m_Material;

        /// <inheritdoc/>
        public override void Create()
        {
            planarRefPass = new PlanarRefPass(LayerMask);
            planarRefPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        }

        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera.
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            planarRefPass.Setup(renderer, m_Material, this);
            renderer.EnqueuePass(planarRefPass);
        }

        protected override void Dispose(bool disposing)
        {
            // foreach (var planarRefPass in m_ScriptablePassList)
            // {
            //     planarRefPass?.Dispose();
            //
            // }
            CoreUtils.Destroy(m_Material);
        }
    }
}