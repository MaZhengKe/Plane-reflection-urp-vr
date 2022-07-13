using System;
using UnityEngine;

namespace UnityTemplateProjects
{
    [ExecuteAlways]
    public class MirrorPlanar : MonoBehaviour
    {
        public RenderTexture renderTexture;

        public Vector4 plane
        {
            get
            {
                var normal = transform.forward;
                var d = -Vector3.Dot(normal, transform.position);
                return new Vector4(normal.x, normal.y, normal.z, d);
            }
        }

            /// <summary>
        /// Add or remove the lens flare to the queue of PostProcess
        /// </summary>
        void OnEnable()
        {
            if(renderTexture)
                MirrorPlanarCommon.Instance.AddData(this);
            else
                MirrorPlanarCommon.Instance.RemoveData(this);
        }

        /// <summary>
        /// Remove the lens flare from the queue of PostProcess
        /// </summary>
        void OnDisable()
        {
            MirrorPlanarCommon.Instance.RemoveData(this);
        }
        
        
        void OnValidate()
        {
            if (isActiveAndEnabled && renderTexture != null)
            {
                MirrorPlanarCommon.Instance.AddData(this);
            }
            else
            {
                MirrorPlanarCommon.Instance.RemoveData(this);
            }
        }

        public Matrix4x4 GetViewMat(Vector3 oldPos, Quaternion oldRot)
        {
            var newPos = mirrorPos(oldPos);
            
            var newRot = mirrorRot(oldRot);

            return Matrix4x4.TRS(newPos, newRot, new Vector3(1, 1, -1)).inverse;
        }

        public Quaternion mirrorRot( Quaternion cam)
        {
            var forward = transform.forward;
            var reflect = Vector3.Reflect(cam * Vector3.forward, forward);
            var reflectup = Vector3.Reflect(cam * Vector3.up, forward);

            return Quaternion.LookRotation(reflect, reflectup);
        }

        public Vector3 mirrorPos(Vector3 oldPos)
        {
            var normal = transform.forward;
            var d = -Vector3.Dot(normal, transform.position);

            return oldPos - 2 * (Vector3.Dot(oldPos, normal) + d) * normal;
        }

        public static void MirrorTran(Transform mirror, Transform org)
        {
            mirror.SetPositionAndRotation(getNewPos(org.position), getNewRot(org.rotation));
        }


        public static Vector3 getNewPos(Vector3 oldPos)
        {
            return new Vector3(oldPos.x, -oldPos.y, oldPos.z);
        }

        public static Quaternion getNewRot(Quaternion oldRot)
        {
            var e = oldRot.eulerAngles;
            var newRot = Quaternion.Euler(new Vector3(-e.x, e.y, -e.z));
            return newRot;
        }
    }
}