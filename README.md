# Plane-reflection-urp-vr 
# 平面反射在VR URP下的实现
前几日去HDRP下试验了各种效果在VR下的可用性，结果是一塌糊涂。像屏幕空间反射、或者Planar probe这种效果官方压根就[没打算支持VR](https://issuetracker.unity3d.com/issues/xr-hdrp-planar-reflection-probes-reflection-is-misaligned-for-both-eyes-when-vr-is-enabled)，只能自力更生了。本着柿子捡软的捏的原则，先从复刻平面探针入手吧。
如果不考虑VR这个实现其实不难，但Unity的单通道渲染实在是太不成熟了，坑一个接一个，这次记录一下踩坑教训。

[说明](https://kuanmi.top/2022/07/01/Plane-reflection-in-VR-URP/)

![镜面效果](https://kuanmi.top/images/mirror05.jpg)
![镜面效果](https://kuanmi.top/images/mirror04.jpg)
