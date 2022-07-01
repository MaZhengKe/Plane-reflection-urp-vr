using PlanarRef;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace PlanarRef
{
    public class PlanarRefFeature : ScriptableRendererFeature
    {
        PlanarRefPass m_ScriptablePass;
        public bool drawSkybox;
        public LayerMask LayerMask = ~0;
        private Material m_Material;

        /// <inheritdoc/>
        public override void Create()
        {
            m_ScriptablePass = new PlanarRefPass(LayerMask);
            

            // Configures where the render pass should be injected.
            m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        // Here you can inject one or multiple render passes in the renderer.
        // This method is called when setting up the renderer once per-camera.
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            m_ScriptablePass.Setup(renderer, m_Material,this);
            renderer.EnqueuePass(m_ScriptablePass);
        }

        protected override void Dispose(bool disposing)
        {
            m_ScriptablePass?.Dispose();
            m_ScriptablePass = null;

            CoreUtils.Destroy(m_Material);
        }
    }
}