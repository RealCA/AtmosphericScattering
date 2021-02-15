using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AtmosphericScatteringBlitPass : ScriptableRendererFeature
{
    public RenderPassEvent PassEvent;
    AtmosphericScatteringPass m_ScriptablePass;
    public override void Create()
    {
        AtmosphericScattering scattering = FindObjectOfType<AtmosphericScattering>();
        if (!scattering)
            scattering = Camera.main.gameObject.AddComponent<AtmosphericScattering>();
        scattering.Start();
        m_ScriptablePass = new AtmosphericScatteringPass(PassEvent, scattering);

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = PassEvent;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTarget, RenderTargetHandle.CameraTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }

    class AtmosphericScatteringPass : ScriptableRenderPass
    {
        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        AtmosphericScattering scattering;
        public AtmosphericScatteringPass(RenderPassEvent evt, AtmosphericScattering scattering)
        {
            renderPassEvent = evt;
            if (scattering == null)
            {
                Debug.Log("No Scattering");
                return;
            }
            this.scattering = scattering;
        }

        RenderTargetIdentifier source;
        RenderTargetHandle destination;

        RenderTargetHandle temporaryColorTexture;

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            if (scattering.rt == null)
            {
                scattering.rt = new RenderTexture(cameraTextureDescriptor);
                scattering.rt.useDynamicScale = true;
            }
            scattering.OnPre();
            base.Configure(cmd, cameraTextureDescriptor);
        }

        public void Setup(RenderTargetIdentifier currentTarget, RenderTargetHandle destination)
        {
            source = currentTarget;
            this.destination = destination;
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("_AtmosphericScatteringPass");
            var mat = scattering.GetMat(cmd, source);
            RenderTextureDescriptor opaqueDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDescriptor.depthBufferBits = 0;
            if (destination == RenderTargetHandle.CameraTarget)
            {
                cmd.GetTemporaryRT(temporaryColorTexture.id, opaqueDescriptor, FilterMode.Point);

                if (!scattering.RenderAtmosphericFog)
                {
                    Blit(cmd, source, temporaryColorTexture.Identifier());
                }
                else
                {
                    Blit(cmd, source, temporaryColorTexture.Identifier(), mat, 3);
                    Blit(cmd, temporaryColorTexture.Identifier(), source);
                }
            }
            else
            {
                if (!scattering.RenderAtmosphericFog)
                {
                    Blit(cmd, source, destination.Identifier());
                }
                else
                {
                    Blit(cmd, source, destination.Identifier(), mat, 3);
                }
            }
            // execution
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
        public override void FrameCleanup(CommandBuffer cmd)
        {


            if (destination == RenderTargetHandle.CameraTarget)
                cmd.ReleaseTemporaryRT(temporaryColorTexture.id);
        }
    }
}