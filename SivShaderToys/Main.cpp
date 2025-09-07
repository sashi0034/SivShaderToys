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

void Main()
{
	ShaderReloader reloader{};

	Texture texture{};

	while (System::Update())
	{
		reloader.Update();

		{
			ScopedCustomShader2D scoped{ reloader.m_ps };
			texture.resized(Scene::Size()).draw();
		}
	}
}
