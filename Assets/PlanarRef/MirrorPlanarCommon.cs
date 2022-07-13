using UnityTemplateProjects;

public class MirrorPlanarCommon
{
    private static MirrorPlanarCommon m_Instance = null;

    private static readonly object m_Padlock = new object();

    private static System.Collections.Generic.List<MirrorPlanar> m_Data = new System.Collections.Generic.List<MirrorPlanar>();

    /// <summary>
    /// Current unique instance
    /// </summary>
    public static MirrorPlanarCommon Instance
    {
        get
        {
            if (m_Instance == null)
            {
                lock (m_Padlock)
                {
                    if (m_Instance == null)
                    {
                        m_Instance = new MirrorPlanarCommon();
                    }
                }
            }

            return m_Instance;
        }
    }
    

    private System.Collections.Generic.List<MirrorPlanar> Data { get { return MirrorPlanarCommon.m_Data; } }

    /// <summary>
    /// Return the pool of Lens Flare added
    /// </summary>
    /// <returns>The Lens Flare Pool</returns>
    public System.Collections.Generic.List<MirrorPlanar> GetData()
    {
        return Data;
    }

    /// <summary>
    /// Check if we have at least one Lens Flare added on the pool
    /// </summary>
    /// <returns>true if no Lens Flare were added</returns>
    public bool IsEmpty()
    {
        return Data.Count == 0;
    }

    /// <summary>
    /// Add a new lens flare component on the pool.
    /// </summary>
    /// <param name="newData">The new data added</param>
    public void AddData(MirrorPlanar newData)
    {
        if (!m_Data.Contains(newData))
        {
            m_Data.Add(newData);
        }
    }
    
    /// <summary>
    /// Remove a lens flare data which exist in the pool.
    /// </summary>
    /// <param name="data">The data which exist in the pool</param>
    public void RemoveData(MirrorPlanar data)
    {
        if (m_Data.Contains(data))
        {
            m_Data.Remove(data);
        }
    }
}