using System.Collections.Generic;
using Unity.Entities;
using Unity.Jobs;
using Unity.Physics;
using Unity.Mathematics;
using Unity.Physics.Systems;
using Unity.Collections;
using Unity.Burst;

namespace MullerLucas.BP.Navigation.FlowField
{
    [UpdateInGroup(typeof(NavigationSimulationSystemGroup))]
    public class CostSystem : SystemBase
    {
        //=============================================================================================================================
        #region constants

        private const float TOLERANCE = 0.05f;

        #endregion constants
        //=============================================================================================================================
        #region fields

        private BuildPhysicsWorld buildPhysicsWorldSystem;
        private CollisionWorld collisionWorld;
        private CollisionFilter collisionFilter;
        private EntityQuery segmentQuery;
        private EntityQuery fieldQuery;
        private BeginInitializationEntityCommandBufferSystem commandBufferSystem;

        #endregion fields
        //=============================================================================================================================
        #region protected methods

        protected unsafe override void OnCreate()
        {
            segmentQuery = GetEntityQuery(new EntityQueryDesc
            {
                All = new ComponentType[]
                {
                    ComponentType.ReadOnly<WorldTopLeftPosition>(),
                    ComponentType.ReadOnly<CellCost>(),
                    ComponentType.ReadOnly<UpdateCostTag>(),
                    ComponentType.ReadOnly<SharedUnitSize>(),
                },
            });

            fieldQuery = GetEntityQuery(new EntityQueryDesc
            {
                All = new ComponentType[]
                {
                    ComponentType.ReadOnly<SegmentDimension>()
                }
            });

            buildPhysicsWorldSystem = World.DefaultGameObjectInjectionWorld.GetOrCreateSystem<BuildPhysicsWorld>();

            uint collisionMask = 1 << 10;
            collisionFilter = new CollisionFilter
            {
                BelongsTo = collisionMask,
                CollidesWith = collisionMask,
                GroupIndex = 0
            };

            commandBufferSystem = World.DefaultGameObjectInjectionWorld.GetOrCreateSystem<BeginInitializationEntityCommandBufferSystem>();

            RequireForUpdate(segmentQuery);
            RequireSingletonForUpdate<SegmentDimension>();
        }

        protected unsafe override void OnUpdate()
        {
            Dependency = JobHandle.CombineDependencies(Dependency, buildPhysicsWorldSystem.GetOutputDependency());
            Dependency.Complete();
            collisionWorld = buildPhysicsWorldSystem.PhysicsWorld.CollisionWorld;

            int segmentDimension = fieldQuery.GetSingleton<SegmentDimension>();

            List<SharedUnitSize> unitSizes = new List<SharedUnitSize>();
            EntityManager.GetAllUniqueSharedComponentData<SharedUnitSize>(unitSizes);

            for (int i = 0; i < unitSizes.Count; i++)
            {
                if (unitSizes[i].Value == 0) { continue; }
                segmentQuery.SetSharedComponentFilter(unitSizes[i]);

                ParallelForSegmentVariant(segmentDimension, unitSizes[i]);
            }
        }

        #endregion protected methods
        //=============================================================================================================================
        #region private methods

        private void ParallelForSegmentVariant(int segmentDimension, float unitSizes)
        {
            int segmentCount = segmentQuery.CalculateEntityCount();

            TestCellJob testCellJob = new TestCellJob
            {
                SegmentEntities = segmentQuery.ToEntityArray(Allocator.TempJob),
                WorldTopLeftPositions = segmentQuery.ToComponentDataArray<WorldTopLeftPosition>(Allocator.TempJob),
                ColliderCastInput = CreateColliderCastInput((unitSizes / 2), collisionFilter),
                CollisionWorld = collisionWorld,
                CellCostBufferFromEntity = GetBufferFromEntity<CellCost>(false),
                SegmentDimension = segmentDimension
            };

            JobHandle testCellJobHandle = testCellJob.Schedule(segmentCount, 1, Dependency);
            Dependency = JobHandle.CombineDependencies(Dependency, testCellJobHandle);

            commandBufferSystem.CreateCommandBuffer().RemoveComponent<UpdateCostTag>(segmentQuery);
            commandBufferSystem.AddJobHandleForProducer(testCellJobHandle);
        }

        private static unsafe ColliderCastInput CreateColliderCastInput(float radius, CollisionFilter collisionFilter)
        {
            SphereGeometry sphereGeometry = new SphereGeometry
            {
                Center = float3.zero,
                Radius = radius - TOLERANCE,
            };

            BlobAssetReference<Collider> sphereColliderReference = SphereCollider.Create(sphereGeometry, collisionFilter);

            ColliderCastInput colliderCastInput = new ColliderCastInput
            {
                Collider = (Collider*)sphereColliderReference.GetUnsafePtr(),
            };

            return colliderCastInput;
        }

        #endregion private methods
        //=============================================================================================================================
        #region jobs

        [BurstCompile]
        struct TestCellJob : IJobParallelFor
        {
            [ReadOnly, DeallocateOnJobCompletion]
            public NativeArray<Entity> SegmentEntities;
            [ReadOnly, DeallocateOnJobCompletion]
            public NativeArray<WorldTopLeftPosition> WorldTopLeftPositions;

            [ReadOnly]
            public ColliderCastInput ColliderCastInput;
            [ReadOnly]
            public CollisionWorld CollisionWorld;

            [NativeDisableParallelForRestriction]
            public BufferFromEntity<CellCost> CellCostBufferFromEntity;

            public int SegmentDimension;


            public void Execute(int index)
            {
                float cellWorldSize = Cell.WORLD_SIZE;
                DynamicBuffer<CellCost> cellCostBuffer = CellCostBufferFromEntity[SegmentEntities[index]];
                float startOffset = cellWorldSize / 2;

                float3 currentCellCenterPosition = WorldTopLeftPositions[index].Value;
                currentCellCenterPosition.z -= startOffset;
                float xStartPosition = currentCellCenterPosition.x + startOffset;

                byte cost;
                for (int y = 0; y < SegmentDimension; y++)
                {
                    currentCellCenterPosition.x = xStartPosition;
                    for (int x = 0; x < SegmentDimension; x++)
                    {
                        ColliderCastInput.Start = currentCellCenterPosition;
                        ColliderCastInput.End = currentCellCenterPosition;
                        cost = (CollisionWorld.CastCollider(ColliderCastInput, out _) ? Cell.BLOCKED_CELL_COST : Cell.DEFAULT_CELL_COST);

                        cellCostBuffer.Add(cost);

                        currentCellCenterPosition.x += cellWorldSize;
                    }
                    currentCellCenterPosition.z -= cellWorldSize;
                }
            }
        }

        #endregion jobs
        //=============================================================================================================================
    }
}
