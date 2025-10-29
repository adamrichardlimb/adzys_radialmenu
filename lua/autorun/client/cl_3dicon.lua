local renderTarget = GetRenderTarget( 
    "RenderTargetExample", -- The name we'll call new Render Target's Texture
    1024, 1024 -- The size of the Render Target
)

-- Create a Material that corresponds to the Render Target we just made
local renderTargetMaterial = CreateMaterial( 
    "RenderTargetExampleMaterial", -- All Materials need a name
    "UnlitGeneric", -- This shader will work great for drawing onto the screen, but can't be used on models
                    -- To use this material on a model, this would need to use the "VertexLitGeneric" shader.
    {
	    ["$basetexture"] = renderTarget:GetName(), -- Use our Render Target as the Texture for this Material
        ["$translucent"] = "1", -- Without this, the Material will be fully opaque and any translucency won't be shown
    } 
)

local clientsideModel = ClientsideModel( "models/props_lab/huladoll.mdl", RENDERGROUP_OPAQUE )
clientsideModel:SetNoDraw( true )

local function DrawSomething3D()

    -- To brighten the model without setting up lighting
    render.SuppressEngineLighting( true )

    -- By default, 3D rendering to a Render Target will put the Depth Buffer into the alpha channel of the image.
    -- I do not know why this is the case, but we can disable that behavior with this function.
    render.SetWriteDepthToDestAlpha( false )

    render.ModelMaterialOverride(Material( "models/wireframe" ))
    render.Model( { 
        model = "models/props_lab/huladoll.mdl", 
        -- You can ignore this math, it's just to make the hula doll do a little dance
        pos = Vector( 20, -math.sin( CurTime() * 7.5 ) * 0.35, -3.5 ), 
        angle = Angle( 0, 180 + math.sin( CurTime() * 7.5 ) * 7, math.sin( CurTime() * 7.5 ) * 15 ) 
    }, clientsideModel )
    render.ModelMaterialOverride(nil)

    render.SetWriteDepthToDestAlpha( true )
    render.SuppressEngineLighting( false )
end

hook.Add( "PreDrawEffects", "DrawingToExampleRenderTarget", function() 
    -- Start drawing onto our render target
    render.PushRenderTarget( renderTarget )

    -- Remove the Render Target's contents from the previous frame so we can draw a new one on a fresh "canvas"
    render.Clear( 0, 0, 0, 200, true, true )


    -- The hook's original 3D context has an unknown position and rotation.
    -- Because we want control over our Render Target, we need to start a new 3D context.
    -- You can think of this as setting up the "camera" we're about to render with. 
    cam.Start3D( 
        Vector( 0, 0, 0 ), -- The position of this 3D context's view
        Angle( 0, 0, 0 ),  -- The direction this 3D context's view is pointing in
        40                 -- The field of view, in degrees
    )
    
    -- Now that we're in a 3D context, let's draw something 3D
    DrawSomething3D()
    
    cam.End3D()

    -- Stop drawing on our render target and let the rendering system continue normally
    render.PopRenderTarget()
end )

-- In a completely different hook we can draw the Render Target to the screen via its Material
-- This is done in a different hook purely to demonstrate that the Render Target can be used
-- outside of the place it is drawn in.
hook.Add( "DrawOverlay", "DrawingRenderTargetToScreen", function()
    surface.SetMaterial( renderTargetMaterial )
    surface.SetDrawColor( Color( 255, 255, 255, 255 ) )
    surface.DrawTexturedRectRotated( 300, 300, 500, 500, 0 )
end )
