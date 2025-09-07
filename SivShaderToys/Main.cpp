# include <Siv3D.hpp> // Siv3D v0.6.16

class ShaderReloader
{
public:
	DirectoryWatcher m_watcher{ U"shader" };

	PixelShader m_ps{};

	ShaderReloader()
	{
		Reload();
	}

	bool Update()
	{
		const Array<FileChange> changes = m_watcher.retrieveChanges();
		if (not changes.empty())
		{
			m_watcher.clearChanges();
			Reload();
		}

		return true;
	}

	void Reload()
	{
		m_ps = PixelShader::HLSL(U"shader/sandbox.hlsl"_sv);
	}
};

struct SandboxData_cb1 {
	Float2 g_resolution;
	float g_time;
};

void Main()
{
	ShaderReloader reloader{};

	Texture texture{};

	ConstantBuffer<SandboxData_cb1> cb1{};

	while (System::Update())
	{
		reloader.Update();

		{
			cb1->g_resolution = Float2(Scene::Size());
			cb1->g_time = static_cast<float>(Scene::Time());
			Graphics2D::SetPSConstantBuffer(1, cb1);

			ScopedCustomShader2D scoped{ reloader.m_ps };
			texture.resized(Scene::Size()).draw();
		}
	}
}
