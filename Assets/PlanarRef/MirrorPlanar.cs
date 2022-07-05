using System;
using UnityEngine;

namespace UnityTemplateProjects
{
    [ExecuteAlways]
    public class MirrorPlanar : MonoBehaviour
    {
        public static Transform Plane;

        private void Update()
        {
            Plane = transform;
        }

        public static Matrix4x4 GetViewMat(Vector3 oldPos, Quaternion oldRot)
        {
            var newPos = mirrorPos(Plane, oldPos);
            
            var newRot = mirrorRot(Plane, oldRot);

            return Matrix4x4.TRS(newPos, newRot, new Vector3(1, 1, -1)).inverse;
        }

        public static Quaternion mirrorRot(Transform plane, Quaternion cam)
        {
            var forward = plane.forward;
            var reflect = Vector3.Reflect(cam * Vector3.forward, forward);
            var reflectup = Vector3.Reflect(cam * Vector3.up, forward);

            return Quaternion.LookRotation(reflect, reflectup);
        }

        public static Vector3 mirrorPos(Transform plane, Vector3 oldPos)
        {
            var normal = plane.forward;
            var d = -Vector3.Dot(normal, plane.position);

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