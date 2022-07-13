using UnityEngine.Rendering;
using UnityTemplateProjects;

public class MirrorPlanarCommon
{
    private static MirrorPlanarCommon m_Instance = null;

    private static readonly object m_Padlock = new object();

    private static System.Collections.Generic.List<MirrorPlanar> m_Data = new System.Collections.Generic.List<MirrorPlanar>();

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

    public System.Collections.Generic.List<MirrorPlanar> GetData()
    {
        return Data;
    }

    public bool IsEmpty()
    {
        return Data.Count == 0;
    }

    public void AddData(MirrorPlanar newData)
    {
        if (!m_Data.Contains(newData))
        {
            m_Data.Add(newData);
            newData.Init();
        }
    }
    
    public void RemoveData(MirrorPlanar data)
    {
        if (m_Data.Contains(data))
        {
            m_Data.Remove(data);
        }
    }
}